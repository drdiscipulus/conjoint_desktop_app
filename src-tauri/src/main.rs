#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::{
    ffi::OsString,
    fs,
    net::{SocketAddr, TcpListener, TcpStream},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    sync::Mutex,
    thread,
    time::{Duration, Instant},
};
use tauri::{
    webview::{DownloadEvent, Webview},
    Emitter, Manager, RunEvent, WebviewWindowBuilder,
};
use url::Url;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

const HOST: &str = "127.0.0.1";
#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;
const SHINY_DOWNLOAD_LINK_SCRIPT: &str = r#"
(() => {
  if (window.__CONJOINT_DESKTOP_DOWNLOADS_BOUND) {
    return;
  }
  window.__CONJOINT_DESKTOP_DOWNLOADS_BOUND = true;

  const isLocalShinyPage = () => /^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(window.location.origin);

  const normalizeDownloadLinks = () => {
    if (!isLocalShinyPage() || !document.querySelectorAll) {
      return;
    }

    document.querySelectorAll('a.shiny-download-link').forEach((link) => {
      if (link.getAttribute('target') !== '_self') {
        link.setAttribute('target', '_self');
      }
    });
  };

  document.addEventListener('click', (event) => {
    const target = event.target;
    const link = target && target.closest ? target.closest('a.shiny-download-link') : null;
    if (link && isLocalShinyPage()) {
      link.setAttribute('target', '_self');

      if (link.classList.contains('disabled') || link.hasAttribute('disabled')) {
        return;
      }

      if (window.Shiny && window.Shiny.setInputValue && link.id) {
        event.preventDefault();
        event.stopImmediatePropagation();
        window.Shiny.setInputValue('desktop_download_request', {
          id: link.id,
          nonce: Date.now() + Math.random()
        }, { priority: 'event' });
      }
    }
  }, true);

  const startObserver = () => {
    normalizeDownloadLinks();
    if (window.MutationObserver && document.documentElement) {
      new MutationObserver(normalizeDownloadLinks).observe(document.documentElement, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: ['href', 'target', 'class']
      });
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startObserver, { once: true });
  } else {
    startObserver();
  }
})();
"#;

#[derive(Default)]
struct ShinyProcessState(Mutex<Option<Child>>);

struct ResourceLayout {
    root: PathBuf,
    shiny_app: PathBuf,
    launch_script: PathBuf,
    rscript: PathBuf,
    r_home: Option<PathBuf>,
    r_library: Option<PathBuf>,
    download_dir: Option<PathBuf>,
}

fn main() {
    tauri::Builder::default()
        .manage(ShinyProcessState::default())
        .invoke_handler(tauri::generate_handler![save_shiny_download])
        .setup(|app| {
            create_main_window(app)?;

            let app_handle = app.handle().clone();
            thread::spawn(move || {
                if let Err(error) = start_and_open_shiny(app_handle) {
                    eprintln!("Could not start Conjoint Companion Shiny backend: {error}");
                }
            });
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building Tauri application")
        .run(|app, event| {
            if let RunEvent::Exit = event {
                stop_shiny(app);
            }
        });
}

fn create_main_window(app: &tauri::App) -> tauri::Result<()> {
    let window_config = app
        .config()
        .app
        .windows
        .first()
        .expect("main window config is missing");

    WebviewWindowBuilder::from_config(app, window_config)?
        .initialization_script(SHINY_DOWNLOAD_LINK_SCRIPT)
        .on_download(handle_download)
        .build()?;

    Ok(())
}

#[tauri::command]
fn save_shiny_download(
    app: tauri::AppHandle,
    filename: String,
    bytes: Vec<u8>,
) -> Result<String, String> {
    let base_dir = executable_directory()
        .or_else(|_| app.path().download_dir())
        .or_else(|_| std::env::current_dir())
        .map_err(|error| format!("Could not resolve a download folder: {error}"))?;
    fs::create_dir_all(&base_dir).map_err(|error| {
        format!(
            "Could not create download folder {}: {error}",
            base_dir.display()
        )
    })?;

    let path = unique_download_path(base_dir.join(sanitize_download_filename(&filename)));
    fs::write(&path, bytes)
        .map_err(|error| format!("Could not write download file {}: {error}", path.display()))?;

    Ok(path.display().to_string())
}

fn executable_directory() -> Result<PathBuf, std::io::Error> {
    let executable = std::env::current_exe()?;
    Ok(executable
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(PathBuf::new))
}

fn handle_download<R: tauri::Runtime>(webview: Webview<R>, event: DownloadEvent<'_>) -> bool {
    match event {
        DownloadEvent::Requested { url, destination } => {
            if let Some(path) = download_destination(&webview, &url, destination) {
                *destination = path;
            }
        }
        DownloadEvent::Finished { url, path, success } => {
            if !success {
                eprintln!("Download failed for {url}; target path was {path:?}");
            }
        }
        _ => {}
    }

    true
}

fn download_destination<R: tauri::Runtime>(
    webview: &Webview<R>,
    url: &Url,
    suggested_destination: &Path,
) -> Option<PathBuf> {
    let base_dir = webview
        .path()
        .download_dir()
        .or_else(|_| std::env::current_dir())
        .ok()?;
    let _ = fs::create_dir_all(&base_dir);

    let filename = suggested_destination
        .file_name()
        .filter(|name| !name.is_empty())
        .map(OsString::from)
        .unwrap_or_else(|| filename_from_url(url));

    Some(unique_download_path(base_dir.join(filename)))
}

fn filename_from_url(url: &Url) -> OsString {
    url.path_segments()
        .and_then(|mut segments| segments.next_back())
        .filter(|segment| !segment.is_empty())
        .map(OsString::from)
        .unwrap_or_else(|| OsString::from("conjoint-companion-download"))
}

fn sanitize_download_filename(filename: &str) -> OsString {
    let filename = filename
        .rsplit(['/', '\\'])
        .next()
        .unwrap_or("conjoint-companion-download")
        .trim();
    let mut sanitized = String::with_capacity(filename.len());

    for character in filename.chars() {
        if character.is_ascii_alphanumeric()
            || matches!(character, '.' | '_' | '-' | ' ' | '(' | ')')
        {
            sanitized.push(character);
        } else {
            sanitized.push('_');
        }
    }

    let sanitized = sanitized.trim().trim_matches('.');
    if sanitized.is_empty() {
        OsString::from("conjoint-companion-download")
    } else {
        OsString::from(sanitized)
    }
}

fn unique_download_path(path: PathBuf) -> PathBuf {
    if !path.exists() {
        return path;
    }

    let parent = path
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(PathBuf::new);
    let stem = path
        .file_stem()
        .map(|value| value.to_string_lossy().into_owned())
        .unwrap_or_else(|| "download".to_string());
    let extension = path.extension().map(OsString::from);

    for index in 1.. {
        let mut filename = OsString::from(format!("{stem} ({index})"));
        if let Some(extension) = &extension {
            filename.push(".");
            filename.push(extension);
        }

        let candidate = parent.join(filename);
        if !candidate.exists() {
            return candidate;
        }
    }

    unreachable!("download filename search is unbounded")
}

fn start_and_open_shiny(app: tauri::AppHandle) -> Result<(), String> {
    emit_status(&app, "Preparing bundled Shiny resources.");
    let layout = resolve_resource_layout(&app)?;
    let port = find_available_port(HOST)?;

    emit_status(&app, "Starting local R/Shiny process.");
    let child = start_shiny_process(&layout, port)?;
    {
        let state = app.state::<ShinyProcessState>();
        *state
            .0
            .lock()
            .map_err(|_| "Shiny process state is unavailable.")? = Some(child);
    }

    if !wait_for_local_port(HOST, port, Duration::from_secs(20)) {
        stop_shiny(&app);
        let message = format!("The local Shiny app did not become ready on {HOST}:{port}.");
        emit_error(&app, &message);
        return Err(message);
    }

    let url = format!("http://{HOST}:{port}");
    emit_status(&app, "Opening Conjoint Companion.");
    let window = app
        .get_webview_window("main")
        .ok_or_else(|| "Main window is unavailable.".to_string())?;
    let parsed_url =
        Url::parse(&url).map_err(|error| format!("Invalid Shiny URL {url}: {error}"))?;
    window
        .navigate(parsed_url)
        .map_err(|error| format!("Could not navigate to local Shiny app: {error}"))?;

    Ok(())
}

fn resolve_resource_layout(app: &tauri::AppHandle) -> Result<ResourceLayout, String> {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let dev_root = manifest_dir.join("resources");
    let bundled_root = app.path().resource_dir().ok();

    let mut root_candidates = vec![dev_root];
    if let Some(bundled_root) = bundled_root {
        root_candidates.push(bundled_root.join("resources"));
        root_candidates.push(bundled_root);
    }
    let root = root_candidates
        .into_iter()
        .find(|candidate| candidate.join("desktop").join("run_shiny.R").is_file())
        .ok_or_else(|| "Could not resolve bundled Shiny resources.".to_string())?;

    let shiny_app = root.join("shiny-app");
    let launch_script = root.join("desktop").join("run_shiny.R");
    if !shiny_app.join("app.R").is_file() {
        return Err(format!(
            "Bundled Shiny app is missing app.R at {}.",
            shiny_app.display()
        ));
    }
    if !launch_script.is_file() {
        return Err(format!(
            "Bundled Shiny launch script is missing at {}.",
            launch_script.display()
        ));
    }

    let r_home = bundled_r_home(&root);
    let rscript = rscript_candidates(&root, r_home.as_deref())
        .into_iter()
        .find(|candidate| candidate.is_file())
        .unwrap_or_else(|| PathBuf::from("Rscript"));
    let r_library = root
        .join("runtime")
        .join("R-library")
        .is_dir()
        .then(|| root.join("runtime").join("R-library"));
    let download_dir = executable_directory()
        .or_else(|_| app.path().download_dir())
        .ok();

    Ok(ResourceLayout {
        root,
        shiny_app,
        launch_script,
        rscript,
        r_home,
        r_library,
        download_dir,
    })
}

fn bundled_r_home(root: &Path) -> Option<PathBuf> {
    let candidate = root.join("runtime").join("R");
    candidate.is_dir().then_some(candidate)
}

fn rscript_candidates(root: &Path, r_home: Option<&Path>) -> Vec<PathBuf> {
    let mut candidates = Vec::new();
    if let Some(r_home) = r_home {
        if cfg!(windows) {
            candidates.push(r_home.join("bin").join("Rscript.exe"));
            candidates.push(r_home.join("bin").join("x64").join("Rscript.exe"));
        } else {
            candidates.push(r_home.join("bin").join("Rscript"));
        }
    }

    if cfg!(windows) {
        candidates.push(
            root.join("runtime")
                .join("R")
                .join("bin")
                .join("Rscript.exe"),
        );
    } else {
        candidates.push(root.join("runtime").join("R").join("bin").join("Rscript"));
    }
    candidates
}

fn start_shiny_process(layout: &ResourceLayout, port: u16) -> Result<Child, String> {
    let mut command = Command::new(&layout.rscript);
    command
        .arg(&layout.launch_script)
        .current_dir(&layout.root)
        .env("CONJOINT_SHINY_APP_DIR", &layout.shiny_app)
        .env("CONJOINT_SHINY_HOST", HOST)
        .env("CONJOINT_SHINY_PORT", port.to_string())
        .env("R_DEFAULT_PACKAGES", "NULL")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    if let Some(r_home) = &layout.r_home {
        command.env("R_HOME", r_home);
    }
    if let Some(r_library) = &layout.r_library {
        command
            .env("CONJOINT_R_LIBRARY", r_library)
            .env("R_LIBS_USER", r_library);
    }
    if let Some(download_dir) = &layout.download_dir {
        command.env("CONJOINT_DOWNLOAD_DIR", download_dir);
    }

    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    command.spawn().map_err(|error| {
        format!(
            "Could not start Rscript from {}: {error}",
            layout.rscript.display()
        )
    })
}

fn stop_shiny(app: &tauri::AppHandle) {
    let state = app.state::<ShinyProcessState>();
    let Ok(mut guard) = state.0.lock() else {
        return;
    };
    if let Some(mut child) = guard.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
}

fn find_available_port(host: &str) -> Result<u16, String> {
    let listener = TcpListener::bind((host, 0))
        .map_err(|error| format!("Could not reserve a local port on {host}: {error}"))?;
    let port = listener
        .local_addr()
        .map_err(|error| format!("Could not read the reserved local port: {error}"))?
        .port();
    drop(listener);
    Ok(port)
}

fn wait_for_local_port(host: &str, port: u16, timeout: Duration) -> bool {
    let Ok(address) = format!("{host}:{port}").parse::<SocketAddr>() else {
        return false;
    };
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if TcpStream::connect_timeout(&address, Duration::from_millis(250)).is_ok() {
            return true;
        }
        thread::sleep(Duration::from_millis(200));
    }
    false
}

fn emit_status(app: &tauri::AppHandle, message: &str) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.emit("shiny-startup-status", message);
    }
}

fn emit_error(app: &tauri::AppHandle, message: &str) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.emit("shiny-startup-error", message);
    }
}
