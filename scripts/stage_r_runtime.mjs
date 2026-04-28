import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const resourcesRoot = path.join(repoRoot, "src-tauri", "resources");
const runtimeRoot = path.join(resourcesRoot, "runtime");
const rDestination = path.join(runtimeRoot, "R");
const libraryDestination = path.join(runtimeRoot, "R-library");
const shinyAppRoot = path.join(resourcesRoot, "shiny-app");
const expectedRVersion = "4.5.3";

function runR(args, options = {}) {
  const output = execFileSync("Rscript", args, {
    cwd: repoRoot,
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options
  });
  return typeof output === "string" ? output.trim() : "";
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

function ensureInsideResources(targetPath) {
  const resolved = path.resolve(targetPath);
  if (!resolved.startsWith(path.resolve(resourcesRoot) + path.sep)) {
    throw new Error(`Refusing to write outside resources: ${resolved}`);
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
  ensureInsideResources(directory);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
}

function copyRuntime(rHome) {
  cleanDirectory(rDestination);
  cpSync(rHome, rDestination, {
    recursive: true,
    force: true,
    filter: runtimeFilter
  });
}

function restoreLibrary() {
  if (!existsSync(path.join(shinyAppRoot, "renv.lock"))) {
    throw new Error("The copied Shiny app is missing renv.lock. Run the renv snapshot step first.");
  }

  cleanDirectory(libraryDestination);
  const restoreScript = [
    `project <- normalizePath(${JSON.stringify(shinyAppRoot)}, mustWork = TRUE)`,
    `library <- normalizePath(${JSON.stringify(libraryDestination)}, mustWork = TRUE)`,
    "renv::restore(project = project, library = library, clean = TRUE, prompt = FALSE)"
  ].join("; ");
  runR(["-e", restoreScript], { stdio: "inherit" });
}

function writeManifest(rInfo) {
  const manifest = {
    generated_at: new Date().toISOString(),
    platform: process.platform,
    arch: process.arch,
    r_version: rInfo.version,
    r_platform: rInfo.platform,
    r_home_source: rInfo.home,
    runtime_path: path.relative(repoRoot, rDestination),
    library_path: path.relative(repoRoot, libraryDestination)
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

  console.log(`Staging R ${rInfo.version} from ${rInfo.home}`);
  copyRuntime(rInfo.home);

  console.log(`Restoring R package library into ${libraryDestination}`);
  restoreLibrary();

  writeManifest(rInfo);
  const runtimeSummary = summarize(rDestination);
  const librarySummary = summarize(libraryDestination);
  console.log(`R runtime files: ${runtimeSummary.fileCount}`);
  console.log(`R library files: ${librarySummary.fileCount}`);
}

main();
