#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::{
    ffi::OsString,
    fs::{self, OpenOptions},
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
const SHINY_DESKTOP_BRIDGE_SCRIPT: &str = r#"
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

  // WebKit occasionally fails Shiny's session-specific HTTP upload request.
  // In the desktop build, send the selected file over the existing local
  // Shiny WebSocket instead. The server still applies the same type, size,
  // dimension, and schema validation as it does for browser uploads.
  document.addEventListener('change', (event) => {
    const input = event.target;
    if (!(input instanceof HTMLInputElement) || input.id !== 'upload_data' || input.type !== 'file') {
      return;
    }

    const file = input.files && input.files[0];
    if (!file || !window.Shiny || !window.Shiny.setInputValue) {
      return;
    }

    event.preventDefault();
    event.stopImmediatePropagation();

    const reader = new FileReader();
    reader.onload = () => {
      const result = typeof reader.result === 'string' ? reader.result : '';
      const separator = result.indexOf(',');
      const encoded = separator >= 0 ? result.slice(separator + 1) : '';
      window.Shiny.setInputValue('desktop_upload_data', {
        name: file.name,
        size: file.size,
        type: file.type || '',
        data: encoded,
        nonce: Date.now() + Math.random()
      }, { priority: 'event' });
    };
    reader.onerror = () => {
      window.Shiny.setInputValue('desktop_upload_error', {
        message: 'The selected file could not be read.',
        nonce: Date.now() + Math.random()
      }, { priority: 'event' });
    };
    reader.readAsDataURL(file);
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

#[derive(Default)]
struct ShinyPortState(Mutex<Option<u16>>);

struct ResourceLayout {
    root: PathBuf,
    shiny_app: PathBuf,
    launch_script: PathBuf,
    rscript: PathBuf,
    uses_r_executable: bool,
    r_home: Option<PathBuf>,
    r_library: Option<PathBuf>,
    download_dir: PathBuf,
}

fn main() {
    tauri::Builder::default()
        .manage(ShinyProcessState::default())
        .manage(ShinyPortState::default())
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

    let app_handle = app.handle().clone();
    WebviewWindowBuilder::from_config(app, window_config)?
        .initialization_script(SHINY_DESKTOP_BRIDGE_SCRIPT)
        .on_download(handle_download)
        .on_navigation(move |url| {
            let port = current_shiny_port(&app_handle);
            is_allowed_navigation(url, port, cfg!(debug_assertions))
        })
        .build()?;

    Ok(())
}

fn handle_download<R: tauri::Runtime>(webview: Webview<R>, event: DownloadEvent<'_>) -> bool {
    match event {
        DownloadEvent::Requested { url, destination } => {
            let port = current_shiny_port(webview.app_handle());
            if !is_expected_shiny_url(&url, port) {
                return false;
            }
            if let Some(path) = download_destination(&webview, &url, destination) {
                *destination = path;
            }
        }
        DownloadEvent::Finished {
            url,
            path,
            success: false,
        } => {
            eprintln!("Download failed for {url}; target path was {path:?}");
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
    let base_dir = webview.path().download_dir().ok()?;
    if ensure_directory_writable(&base_dir).is_err() {
        return None;
    }

    let suggested_filename = suggested_destination
        .file_name()
        .filter(|name| !name.is_empty())
        .map(OsString::from)
        .unwrap_or_else(|| filename_from_url(url));
    let filename = sanitize_download_filename(&suggested_filename.to_string_lossy());

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

    let parent = path.parent().map(Path::to_path_buf).unwrap_or_default();
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

fn ensure_directory_writable(directory: &Path) -> Result<(), String> {
    fs::create_dir_all(directory).map_err(|error| {
        format!(
            "Could not create download folder {}: {error}",
            directory.display()
        )
    })?;

    let probe = directory.join(format!(
        ".conjoint-companion-write-test-{}",
        std::process::id()
    ));
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&probe)
        .map_err(|error| {
            format!(
                "Download folder {} is not writable: {error}",
                directory.display()
            )
        })?;
    fs::remove_file(&probe).map_err(|error| {
        format!(
            "Could not remove download folder write test {}: {error}",
            probe.display()
        )
    })?;
    Ok(())
}

fn current_shiny_port<R: tauri::Runtime>(app: &tauri::AppHandle<R>) -> Option<u16> {
    app.state::<ShinyPortState>()
        .0
        .lock()
        .ok()
        .and_then(|guard| *guard)
}

fn is_expected_shiny_url(url: &Url, expected_port: Option<u16>) -> bool {
    url.scheme() == "http"
        && matches!(url.host_str(), Some("127.0.0.1" | "localhost"))
        && expected_port.is_some_and(|port| url.port() == Some(port))
}

fn is_allowed_navigation(url: &Url, shiny_port: Option<u16>, debug_build: bool) -> bool {
    if matches!(url.scheme(), "tauri" | "asset")
        || matches!(url.host_str(), Some("tauri.localhost"))
    {
        return true;
    }

    if debug_build
        && url.scheme() == "http"
        && url.host_str() == Some(HOST)
        && url.port() == Some(1420)
    {
        return true;
    }

    is_expected_shiny_url(url, shiny_port)
}

fn start_and_open_shiny(app: tauri::AppHandle) -> Result<(), String> {
    emit_status(&app, "Preparing bundled Shiny resources.");
    let layout = resolve_resource_layout(&app)?;
    let port = find_available_port(HOST)?;

    emit_status(&app, "Starting local R/Shiny process.");
    let mut child = start_shiny_process(&layout, port)?;
    {
        let state = app.state::<ShinyProcessState>();
        match state.0.lock() {
            Ok(mut guard) => *guard = Some(child),
            Err(_) => {
                let _ = child.kill();
                let _ = child.wait();
                return Err("Shiny process state is unavailable.".to_string());
            }
        };
    }
    {
        let state = app.state::<ShinyPortState>();
        if let Ok(mut guard) = state.0.lock() {
            *guard = Some(port);
        } else {
            stop_shiny(&app);
            return Err("Shiny port state is unavailable.".to_string());
        };
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
    let bundled_root = app.path().resource_dir().ok().map(|resource_dir| {
        let nested_resources = resource_dir.join("resources");
        if nested_resources.join("shiny-app").join("app.R").is_file() {
            nested_resources
        } else {
            resource_dir
        }
    });

    let root = if cfg!(debug_assertions) && dev_root.join("desktop").join("run_shiny.R").is_file() {
        dev_root
    } else {
        bundled_root.ok_or_else(|| "Could not resolve Tauri resource directory.".to_string())?
    };

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

    let r_home = bundled_r_home(&root, &manifest_dir);
    let uses_r_executable = cfg!(target_os = "macos") && r_home.is_some();
    let rscript = rscript_candidates(&root, r_home.as_deref())
        .into_iter()
        .find(|candidate| candidate.is_file())
        .unwrap_or_else(|| PathBuf::from("Rscript"));
    let r_library = root
        .join("runtime")
        .join("R-library")
        .is_dir()
        .then(|| root.join("runtime").join("R-library"));
    let download_dir = app
        .path()
        .download_dir()
        .map_err(|error| format!("Could not resolve the user Downloads folder: {error}"))?;
    ensure_directory_writable(&download_dir)?;

    Ok(ResourceLayout {
        root,
        shiny_app,
        launch_script,
        rscript,
        uses_r_executable,
        r_home,
        r_library,
        download_dir,
    })
}

fn bundled_r_home(root: &Path, manifest_dir: &Path) -> Option<PathBuf> {
    #[cfg(target_os = "macos")]
    {
        if let Some(bundled_framework) = root
            .ancestors()
            .take(4)
            .map(|ancestor| {
                ancestor
                    .join("Frameworks")
                    .join("R.framework")
                    .join("Resources")
            })
            .find(|candidate| candidate.is_dir())
        {
            return Some(bundled_framework);
        }

        let development_framework = manifest_dir
            .join("bundle-runtime")
            .join("R.framework")
            .join("Resources");
        if cfg!(debug_assertions) && development_framework.is_dir() {
            return Some(development_framework);
        }
    }

    let _ = manifest_dir;
    let candidate = root.join("runtime").join("R");
    candidate.is_dir().then_some(candidate)
}

fn rscript_candidates(root: &Path, r_home: Option<&Path>) -> Vec<PathBuf> {
    let mut candidates = Vec::new();
    if let Some(r_home) = r_home {
        if cfg!(windows) {
            candidates.push(r_home.join("bin").join("Rscript.exe"));
            candidates.push(r_home.join("bin").join("x64").join("Rscript.exe"));
        } else if cfg!(target_os = "macos") {
            candidates.push(r_home.join("bin").join("exec").join("R"));
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
    if layout.uses_r_executable {
        command
            .arg("--no-echo")
            .arg("--no-restore")
            .arg(format!("--file={}", layout.launch_script.display()));
    } else {
        command.arg(&layout.launch_script);
    }
    command
        .current_dir(&layout.root)
        .env("CONJOINT_SHINY_APP_DIR", &layout.shiny_app)
        .env("CONJOINT_SHINY_HOST", HOST)
        .env("CONJOINT_SHINY_PORT", port.to_string())
        .env("RENV_CONFIG_AUTOLOADER_ENABLED", "FALSE")
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
    command.env("CONJOINT_DOWNLOAD_DIR", &layout.download_dir);

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
    if let Ok(mut port) = app.state::<ShinyPortState>().0.lock() {
        *port = None;
    }
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temporary_test_directory(name: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time should follow the Unix epoch")
            .as_nanos();
        std::env::temp_dir().join(format!(
            "conjoint-companion-{name}-{}-{nonce}",
            std::process::id()
        ))
    }

    #[test]
    fn download_filenames_are_reduced_to_safe_basenames() {
        assert_eq!(
            sanitize_download_filename("../results<>.xlsx"),
            OsString::from("results__.xlsx")
        );
        assert_eq!(
            sanitize_download_filename("..."),
            OsString::from("conjoint-companion-download")
        );
    }

    #[test]
    fn unique_download_paths_keep_the_extension() {
        let directory = temporary_test_directory("unique-download");
        fs::create_dir_all(&directory).expect("temporary directory should be created");
        let original = directory.join("results.xlsx");
        fs::write(&original, b"existing").expect("fixture should be written");

        assert_eq!(
            unique_download_path(original),
            directory.join("results (1).xlsx")
        );

        fs::remove_dir_all(directory).expect("temporary directory should be removed");
    }

    #[test]
    fn only_the_active_local_shiny_origin_is_accepted() {
        let active = Url::parse("http://127.0.0.1:43123/results").unwrap();
        let wrong_port = Url::parse("http://127.0.0.1:43124/results").unwrap();
        let remote = Url::parse("https://example.com/results").unwrap();

        assert!(is_expected_shiny_url(&active, Some(43123)));
        assert!(!is_expected_shiny_url(&wrong_port, Some(43123)));
        assert!(!is_expected_shiny_url(&remote, Some(43123)));
        assert!(!is_expected_shiny_url(&active, None));
    }

    #[test]
    fn navigation_allows_loader_dev_server_and_active_shiny_only() {
        let loader = Url::parse("tauri://localhost/").unwrap();
        let dev_server = Url::parse("http://127.0.0.1:1420/").unwrap();
        let shiny = Url::parse("http://localhost:43123/").unwrap();
        let external = Url::parse("https://example.com/").unwrap();

        assert!(is_allowed_navigation(&loader, None, false));
        assert!(is_allowed_navigation(&dev_server, None, true));
        assert!(is_allowed_navigation(&shiny, Some(43123), false));
        assert!(!is_allowed_navigation(&external, Some(43123), false));
    }

    #[test]
    fn download_directory_probe_cleans_up_after_itself() {
        let directory = temporary_test_directory("writable-directory");
        ensure_directory_writable(&directory).expect("temporary directory should be writable");
        assert_eq!(
            fs::read_dir(&directory)
                .expect("temporary directory should exist")
                .count(),
            0
        );
        fs::remove_dir_all(directory).expect("temporary directory should be removed");
    }
}
