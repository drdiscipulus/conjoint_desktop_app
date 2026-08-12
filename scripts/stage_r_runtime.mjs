import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const resourcesRoot = path.join(repoRoot, "src-tauri", "resources");
const runtimeRoot = path.join(resourcesRoot, "runtime");
const bundleRuntimeRoot = path.join(repoRoot, "src-tauri", "bundle-runtime");
const rDestination = path.join(runtimeRoot, "R");
const rFrameworkDestination = path.join(bundleRuntimeRoot, "R.framework");
const libraryDestination = path.join(runtimeRoot, "R-library");
const shinyAppRoot = path.join(resourcesRoot, "shiny-app");
const macosMakevars = path.join(repoRoot, "scripts", "R-Makevars.macos");
const expectedRVersion = "4.5.3";

function runR(args, options = {}) {
  const output = execFileSync("Rscript", args, {
    cwd: repoRoot,
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
    env: rBuildEnv(),
    ...options
  });
  return typeof output === "string" ? output.trim() : "";
}

function prependEnvPath(existing, entries) {
  const presentEntries = entries.filter((entry) => existsSync(entry));
  if (presentEntries.length === 0) {
    return existing;
  }
  return [presentEntries.join(path.delimiter), existing].filter(Boolean).join(path.delimiter);
}

function appendEnvFlags(existing, flags) {
  const presentFlags = flags.filter(Boolean);
  if (presentFlags.length === 0) {
    return existing;
  }
  return [existing, presentFlags.join(" ")].filter(Boolean).join(" ");
}

function rBuildEnv() {
  const brewPrefix = "/opt/homebrew";
  const gccLib = path.join(brewPrefix, "opt", "gcc", "lib", "gcc", "current");
  const gfortran = path.join(brewPrefix, "bin", "gfortran");

  const env = {
    ...process.env,
    PATH: prependEnvPath(process.env.PATH, [
      path.join(brewPrefix, "bin"),
      path.join(brewPrefix, "sbin")
    ]),
    PKG_CONFIG_PATH: prependEnvPath(process.env.PKG_CONFIG_PATH, [
      path.join(brewPrefix, "lib", "pkgconfig"),
      path.join(brewPrefix, "share", "pkgconfig"),
      path.join(brewPrefix, "opt", "openssl@3", "lib", "pkgconfig"),
      path.join(brewPrefix, "opt", "gettext", "lib", "pkgconfig"),
      path.join(brewPrefix, "opt", "harfbuzz", "lib", "pkgconfig"),
      path.join(brewPrefix, "opt", "fribidi", "lib", "pkgconfig"),
      path.join(brewPrefix, "opt", "freetype", "lib", "pkgconfig"),
      path.join(brewPrefix, "opt", "libpng", "lib", "pkgconfig")
    ]),
    CPPFLAGS: appendEnvFlags(process.env.CPPFLAGS, [
      existsSync(path.join(brewPrefix, "include")) ? `-I${path.join(brewPrefix, "include")}` : "",
      existsSync(path.join(brewPrefix, "opt", "gettext", "include")) ? `-I${path.join(brewPrefix, "opt", "gettext", "include")}` : "",
      existsSync(path.join(brewPrefix, "opt", "openssl@3", "include")) ? `-I${path.join(brewPrefix, "opt", "openssl@3", "include")}` : ""
    ]),
    LDFLAGS: appendEnvFlags(process.env.LDFLAGS, [
      existsSync(path.join(brewPrefix, "lib")) ? `-L${path.join(brewPrefix, "lib")}` : "",
      existsSync(path.join(brewPrefix, "opt", "gettext", "lib")) ? `-L${path.join(brewPrefix, "opt", "gettext", "lib")}` : "",
      existsSync(path.join(brewPrefix, "opt", "openssl@3", "lib")) ? `-L${path.join(brewPrefix, "opt", "openssl@3", "lib")}` : ""
    ])
  };

  if (existsSync(gfortran)) {
    env.FC = gfortran;
    env.F77 = gfortran;
  }
  if (existsSync(gccLib)) {
    env.FLIBS = `-L${gccLib} -lgfortran -lquadmath -lm`;
  }
  if (process.platform === "darwin" && existsSync(macosMakevars)) {
    env.R_MAKEVARS_USER = macosMakevars;
  }

  return env;
}

function detectR() {
  const script = [
    "cat(R.home(), '\\n')",
    "cat(as.character(getRversion()), '\\n')",
    "cat(R.version$platform, '\\n')"
  ].join("; ");
  const [home, version, platform] = runR(["-e", script])
    .split(/\r?\n/)
    .map((line) => line.trim());
  if (!home || !version || !platform) {
    throw new Error("Could not detect R home/version/platform from Rscript.");
  }
  if (version !== expectedRVersion && process.env.CONJOINT_ALLOW_OTHER_R_VERSION !== "1") {
    throw new Error(
      `Expected R ${expectedRVersion}, but Rscript reports ${version}. ` +
      "Set CONJOINT_ALLOW_OTHER_R_VERSION=1 only for exploratory builds."
    );
  }
  return {
    home: path.resolve(home),
    version,
    platform
  };
}

function ensureInsideGeneratedRoots(targetPath) {
  const resolved = path.resolve(targetPath);
  const allowedRoots = [runtimeRoot, bundleRuntimeRoot].map((root) => path.resolve(root));
  if (!allowedRoots.some((root) => resolved === root || resolved.startsWith(root + path.sep))) {
    throw new Error(`Refusing to write outside generated runtime roots: ${resolved}`);
  }
}

function runtimeFilter(sourcePath) {
  const name = path.basename(sourcePath);
  if (["doc", "tests", "src"].includes(name)) {
    return false;
  }
  if (name.endsWith(".pdb") || name.endsWith(".log")) {
    return false;
  }
  return true;
}

function cleanDirectory(directory) {
  ensureInsideGeneratedRoots(directory);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
}

function copyWindowsRuntime(rHome) {
  cleanDirectory(rDestination);
  cpSync(rHome, rDestination, {
    recursive: true,
    force: true,
    dereference: true,
    filter: runtimeFilter
  });
}

function findRFramework(rHome) {
  let current = path.resolve(rHome);
  while (current !== path.dirname(current)) {
    if (path.basename(current) === "R.framework") {
      return current;
    }
    current = path.dirname(current);
  }
  throw new Error(`Could not locate R.framework above R home ${rHome}.`);
}

function listFiles(directory) {
  const files = [];
  function walk(current) {
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const currentPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(currentPath);
      } else if (entry.isFile()) {
        files.push(currentPath);
      }
    }
  }
  walk(directory);
  return files;
}

function isMachO(filePath) {
  try {
    return execFileSync("file", ["-b", filePath], { encoding: "utf-8" }).includes("Mach-O");
  } catch {
    return false;
  }
}

function relativeFrameworkReference(reference) {
  const marker = "/R.framework/";
  const markerIndex = reference.indexOf(marker);
  if (markerIndex === -1) {
    return null;
  }
  return `@rpath/R.framework/${reference.slice(markerIndex + marker.length)}`;
}

function patchMacFrameworkReferences() {
  const machOFiles = [
    ...listFiles(rFrameworkDestination),
    ...listFiles(libraryDestination)
  ].filter(isMachO);

  for (const filePath of machOFiles) {
    const dependencies = execFileSync("otool", ["-L", filePath], { encoding: "utf-8" })
      .split(/\r?\n/)
      .slice(1)
      .map((line) => line.trim().split(" ")[0])
      .filter(Boolean);
    for (const dependency of dependencies) {
      const replacement = relativeFrameworkReference(dependency);
      if (replacement && dependency !== replacement) {
        execFileSync("install_name_tool", ["-change", dependency, replacement, filePath]);
      }
    }

    const ids = execFileSync("otool", ["-D", filePath], { encoding: "utf-8" })
      .split(/\r?\n/)
      .slice(1)
      .map((line) => line.trim())
      .filter(Boolean);
    for (const id of ids) {
      const replacement = relativeFrameworkReference(id);
      if (replacement && id !== replacement) {
        execFileSync("install_name_tool", ["-id", replacement, filePath]);
      }
    }
  }

  const rExecutable = path.join(rFrameworkDestination, "Resources", "bin", "exec", "R");
  try {
    execFileSync("install_name_tool", ["-add_rpath", "@executable_path/../../../..", rExecutable]);
  } catch (error) {
    const message = String(error.stderr || error.message || error);
    if (!message.includes("would duplicate path")) {
      throw error;
    }
  }
}

function copyMacRuntime(rHome) {
  if (process.arch !== "arm64") {
    throw new Error(`macOS releases require Apple Silicon arm64, not ${process.arch}.`);
  }
  const frameworkSource = findRFramework(rHome);
  mkdirSync(path.dirname(rFrameworkDestination), { recursive: true });
  rmSync(rFrameworkDestination, { recursive: true, force: true });
  cpSync(frameworkSource, rFrameworkDestination, {
    recursive: true,
    force: true,
    verbatimSymlinks: true
  });
}

function restoreLibrary() {
  if (!existsSync(path.join(shinyAppRoot, "renv.lock"))) {
    throw new Error("The embedded Shiny app is missing renv.lock. Create the lockfile before staging a release runtime.");
  }

  cleanDirectory(libraryDestination);
  const bootstrapScript = [
    `library <- normalizePath(${JSON.stringify(libraryDestination)}, mustWork = TRUE)`,
    ".libPaths(c(library, .libPaths()))",
    "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv', lib = library, repos = 'https://cloud.r-project.org')"
  ].join("; ");
  runR(["-e", bootstrapScript], { stdio: "inherit" });

  const restoreScript = [
    `project <- normalizePath(${JSON.stringify(shinyAppRoot)}, mustWork = TRUE)`,
    `library <- normalizePath(${JSON.stringify(libraryDestination)}, mustWork = TRUE)`,
    ".libPaths(c(library, .libPaths()))",
    "renv::restore(project = project, library = library, clean = TRUE, prompt = FALSE)"
  ].join("; ");
  runR(["-e", restoreScript], { stdio: "inherit" });
  validateRestoredLibrary();
}

function validateRestoredLibrary() {
  const lockfile = path.join(shinyAppRoot, "renv.lock");
  const script = [
    `library <- normalizePath(${JSON.stringify(libraryDestination)}, mustWork = TRUE)`,
    `.libPaths(c(library, .libPaths()))`,
    `lock <- jsonlite::fromJSON(${JSON.stringify(lockfile)}, simplifyVector = FALSE)$Packages`,
    "expected <- vapply(lock, function(record) record$Version, character(1))",
    "installed <- installed.packages(lib.loc = c(library, .Library))[, 'Version']",
    "missing <- setdiff(names(expected), names(installed))",
    "common <- intersect(names(expected), names(installed))",
    "mismatch <- common[expected[common] != installed[common]]",
    "if (length(missing) || length(mismatch)) {",
    "  details <- c(",
    "    if (length(missing)) paste('missing:', paste(missing, collapse = ', ')),",
    "    if (length(mismatch)) paste(sprintf('%s expected %s, installed %s', mismatch, expected[mismatch], installed[mismatch]), collapse = '; ')",
    "  )",
    "  stop(paste('Restored R library does not match renv.lock:', paste(details, collapse = ' | ')))",
    "}",
    "cat(sprintf('Verified %d locked R package versions.\\n', length(expected)))"
  ].join("\n");
  runR(["-e", script], { stdio: "inherit" });
}

function sha256(filePath) {
  return createHash("sha256").update(readFileSync(filePath)).digest("hex");
}

function gitCommit() {
  return execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: repoRoot,
    encoding: "utf-8"
  }).trim();
}

function writeThirdPartyNotices(rInfo) {
  const noticesPath = path.join(runtimeRoot, "THIRD_PARTY_NOTICES.txt");
  const script = [
    `library <- normalizePath(${JSON.stringify(libraryDestination)}, mustWork = TRUE)`,
    "packages <- as.data.frame(installed.packages(lib.loc = c(library, .Library))[, c('Package', 'Version', 'License')], stringsAsFactors = FALSE)",
    "packages <- packages[!duplicated(packages$Package), , drop = FALSE]",
    "packages <- packages[order(packages$Package), , drop = FALSE]",
    `con <- file(${JSON.stringify(noticesPath)}, open = 'wt', encoding = 'UTF-8')`,
    `writeLines(c('Conjoint Companion Desktop - Third-Party Components', '', paste('R', ${JSON.stringify(rInfo.version)}, '- GPL-2 | GPL-3'), ''), con)`,
    "write.table(packages, con, sep = '\\t', row.names = FALSE, quote = FALSE)",
    "close(con)"
  ].join("; ");
  runR(["-e", script]);
}

function writeManifest(rInfo) {
  const runtimePath = process.platform === "darwin"
    ? "Contents/Frameworks/R.framework"
    : "resources/runtime/R";
  const manifest = {
    schema_version: 1,
    app_version: JSON.parse(readFileSync(path.join(repoRoot, "package.json"), "utf-8")).version,
    git_commit: gitCommit(),
    platform: process.platform,
    arch: process.arch,
    r_version: rInfo.version,
    r_platform: rInfo.platform,
    runtime_path: runtimePath,
    library_path: "resources/runtime/R-library",
    renv_lock_sha256: sha256(path.join(shinyAppRoot, "renv.lock")),
    package_lock_sha256: sha256(path.join(repoRoot, "package-lock.json"))
  };
  writeFileSync(path.join(runtimeRoot, "bundle-manifest.json"), JSON.stringify(manifest, null, 2), "utf-8");
}

function summarize(directory) {
  let fileCount = 0;
  let totalBytes = 0;

  function walk(current) {
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const currentPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(currentPath);
      } else if (entry.isFile()) {
        fileCount += 1;
        totalBytes += statSync(currentPath).size;
      }
    }
  }

  walk(directory);
  return { fileCount, totalBytes };
}

function main() {
  const rInfo = detectR();
  mkdirSync(runtimeRoot, { recursive: true });

  console.log(`Staging R ${rInfo.version} for ${process.platform}-${process.arch}`);
  if (process.platform === "darwin") {
    ensureInsideGeneratedRoots(rDestination);
    rmSync(rDestination, { recursive: true, force: true });
    copyMacRuntime(rInfo.home);
  } else if (process.platform === "win32") {
    ensureInsideGeneratedRoots(rFrameworkDestination);
    rmSync(rFrameworkDestination, { recursive: true, force: true });
    copyWindowsRuntime(rInfo.home);
  } else {
    throw new Error(`Release runtime staging is not supported on ${process.platform}.`);
  }

  console.log(`Restoring R package library into ${libraryDestination}`);
  restoreLibrary();

  if (process.platform === "darwin") {
    patchMacFrameworkReferences();
  }

  writeThirdPartyNotices(rInfo);
  writeManifest(rInfo);
  const runtimeSummary = summarize(
    process.platform === "darwin" ? rFrameworkDestination : rDestination
  );
  const librarySummary = summarize(libraryDestination);
  console.log(`R runtime files: ${runtimeSummary.fileCount}`);
  console.log(`R library files: ${librarySummary.fileCount}`);
}

main();
