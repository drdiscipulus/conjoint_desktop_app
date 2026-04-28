import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const defaultSourceRoot = path.resolve(repoRoot, "..", "conjoint_app");
const sourceRoot = path.resolve(process.env.CONJOINT_SHINY_SOURCE || defaultSourceRoot);
const resourcesRoot = path.join(repoRoot, "src-tauri", "resources");
const destinationRoot = path.join(repoRoot, "src-tauri", "resources", "shiny-app");
const preservedRelativePaths = [
  ".Rprofile",
  "README.md",
  "renv.lock",
  path.join("renv", "activate.R"),
  path.join("renv", "settings.json")
];

const excludedNames = new Set([
  ".git",
  ".Rproj.user",
  "dev",
  "README_files",
  "test-results",
  "README.html",
  "Rplots.pdf"
]);

function assertSafePaths() {
  if (!existsSync(path.join(sourceRoot, "app.R"))) {
    if (existsSync(path.join(destinationRoot, "app.R"))) {
      console.warn(`Shiny source app.R was not found at ${sourceRoot}; keeping existing desktop snapshot.`);
      return false;
    }
    throw new Error(`Shiny source app.R was not found at ${sourceRoot}, and no existing desktop snapshot is available.`);
  }

  const resolvedDestination = path.resolve(destinationRoot);
  if (!resolvedDestination.startsWith(path.resolve(resourcesRoot) + path.sep)) {
    throw new Error(`Refusing to sync outside src-tauri/resources: ${resolvedDestination}`);
  }
  return true;
}

function shouldCopy(sourcePath) {
  const name = path.basename(sourcePath);
  if (excludedNames.has(name)) {
    return false;
  }
  if (name.endsWith(".tmp") || name.endsWith(".log")) {
    return false;
  }
  return true;
}

function copyFilteredDirectory(source, destination) {
  mkdirSync(destination, { recursive: true });

  for (const entry of readdirSync(source, { withFileTypes: true })) {
    const sourcePath = path.join(source, entry.name);
    const destinationPath = path.join(destination, entry.name);
    if (!shouldCopy(sourcePath)) {
      continue;
    }

    if (entry.isDirectory()) {
      copyFilteredDirectory(sourcePath, destinationPath);
    } else if (entry.isFile()) {
      cpSync(sourcePath, destinationPath, { force: true });
    }
  }
}

function preserveDesktopOwnedFiles() {
  const preserved = [];
  for (const relativePath of preservedRelativePaths) {
    const absolutePath = path.join(destinationRoot, relativePath);
    if (!existsSync(absolutePath)) {
      continue;
    }
    preserved.push({
      relativePath,
      contents: readFileSync(absolutePath)
    });
  }
  return preserved;
}

function restoreDesktopOwnedFiles(preserved) {
  for (const file of preserved) {
    const absolutePath = path.join(destinationRoot, file.relativePath);
    mkdirSync(path.dirname(absolutePath), { recursive: true });
    writeFileSync(absolutePath, file.contents);
  }
}

function patchCopiedAppForOfflineUse() {
  const appPath = path.join(destinationRoot, "app.R");
  let appSource = readFileSync(appPath, "utf-8");
  appSource = appSource.replace(
    'code_font = font_google("Roboto Mono"),',
    'code_font = "Consolas",'
  );
  writeFileSync(appPath, appSource, "utf-8");
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
  const canRefreshFromSource = assertSafePaths();
  if (!canRefreshFromSource) {
    return;
  }
  const preserved = preserveDesktopOwnedFiles();
  rmSync(destinationRoot, { recursive: true, force: true });
  copyFilteredDirectory(sourceRoot, destinationRoot);
  restoreDesktopOwnedFiles(preserved);
  patchCopiedAppForOfflineUse();

  const summary = summarize(destinationRoot);
  console.log(`Synced Shiny app from ${sourceRoot}`);
  console.log(`Destination: ${destinationRoot}`);
  console.log(`Files: ${summary.fileCount}`);
}

main();
