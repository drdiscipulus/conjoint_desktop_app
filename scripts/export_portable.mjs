import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const packageJson = JSON.parse(readFileSync(path.join(repoRoot, "package.json"), "utf-8"));
const releaseRoot = path.join(repoRoot, "src-tauri", "target", "release");
const artifactsRoot = path.join(repoRoot, "release-artifacts", platformLabel(), "portable");
const stagingRoot = path.join(artifactsRoot, "staging");
const executableName = process.platform === "win32"
  ? "conjoint_companion_desktop.exe"
  : "conjoint_companion_desktop";

function platformLabel() {
  if (process.platform === "win32") {
    return process.arch === "arm64" ? "windows-arm64" : "windows-x64";
  }
  if (process.platform === "darwin") {
    return process.arch === "arm64" ? "macos-arm64" : "macos-x64";
  }
  return `${process.platform}-${process.arch}`;
}

function removeAndCreate(directory) {
  const resolved = path.resolve(directory);
  if (!resolved.startsWith(path.resolve(repoRoot, "release-artifacts") + path.sep)) {
    throw new Error(`Refusing to export outside release-artifacts: ${resolved}`);
  }
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
}

function copyIfPresent(source, destination) {
  if (existsSync(source)) {
    cpSync(source, destination, {
      recursive: true,
      force: true,
      filter: (sourcePath) => path.basename(sourcePath).toLowerCase() !== "rplots.pdf"
    });
    return true;
  }
  return false;
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

function sha256(filePath) {
  return createHash("sha256").update(readFileSync(filePath)).digest("hex");
}

function createWindowsZip(sourceDirectory, archivePath) {
  execFileSync("tar.exe", [
    "-a",
    "-c",
    "-f",
    archivePath,
    "-C",
    path.dirname(sourceDirectory),
    path.basename(sourceDirectory)
  ], { stdio: "inherit" });
}

function createMacZip(appBundle, archivePath) {
  execFileSync("ditto", [
    "-c",
    "-k",
    "--sequesterRsrc",
    "--keepParent",
    appBundle,
    archivePath,
  ], { stdio: "inherit" });
}

function exportWindows() {
  const executablePath = path.join(releaseRoot, executableName);
  if (!existsSync(executablePath)) {
    throw new Error(`Release executable not found at ${executablePath}. Run npm run tauri:build first.`);
  }

  const unexpectedRenvOutput = path.join(releaseRoot, "resources", "shiny-app", "renv");
  if (existsSync(unexpectedRenvOutput)) {
    throw new Error(
      `Refusing to export stale Shiny renv output at ${unexpectedRenvOutput}. ` +
      "Run npm run clean:release-output and rebuild the Tauri application."
    );
  }

  removeAndCreate(artifactsRoot);
  const artifactBaseName = `Conjoint-Companion-v${packageJson.version}-${platformLabel()}`;
  const portableRoot = path.join(stagingRoot, artifactBaseName);
  mkdirSync(portableRoot, { recursive: true });

  cpSync(executablePath, path.join(portableRoot, executableName), { force: true });
  copyIfPresent(path.join(releaseRoot, "resources"), path.join(portableRoot, "resources"));
  cpSync(path.join(repoRoot, "LICENSE"), path.join(portableRoot, "LICENSE"), { force: true });
  cpSync(path.join(repoRoot, "README.md"), path.join(portableRoot, "README.md"), { force: true });
  copyIfPresent(
    path.join(repoRoot, "src-tauri", "resources", "runtime", "THIRD_PARTY_NOTICES.txt"),
    path.join(portableRoot, "THIRD_PARTY_NOTICES.txt")
  );
  writeFileSync(path.join(portableRoot, ".conjoint_companion_portable"), "", "utf-8");

  const archiveName = `${artifactBaseName}.zip`;
  const archivePath = path.join(artifactsRoot, archiveName);
  createWindowsZip(portableRoot, archivePath);

  const digest = sha256(archivePath);
  writeFileSync(path.join(artifactsRoot, "SHA256SUMS.txt"), `${digest}  ${archiveName}\n`, "utf-8");

  const summary = summarize(portableRoot);
  console.log(`Portable staging directory: ${portableRoot}`);
  console.log(`Release archive: ${archivePath}`);
  console.log(`Checksum file: ${path.join(artifactsRoot, "SHA256SUMS.txt")}`);
  console.log(`Files: ${summary.fileCount}`);
}

function exportMac() {
  removeAndCreate(artifactsRoot);
  const appBundle = path.join(
    releaseRoot,
    "bundle",
    "macos",
    "Conjoint Companion.app"
  );
  if (!existsSync(appBundle)) {
    throw new Error(`Signed macOS app bundle not found at ${appBundle}.`);
  }

  const artifactBaseName = `Conjoint-Companion-v${packageJson.version}-${platformLabel()}`;
  const archiveName = `${artifactBaseName}.zip`;
  const archivePath = path.join(artifactsRoot, archiveName);
  createMacZip(appBundle, archivePath);

  const digest = sha256(archivePath);
  writeFileSync(path.join(artifactsRoot, "SHA256SUMS.txt"), `${digest}  ${archiveName}\n`, "utf-8");
  console.log(`Signed macOS app: ${appBundle}`);
  console.log(`Release archive: ${archivePath}`);
  console.log(`Checksum file: ${path.join(artifactsRoot, "SHA256SUMS.txt")}`);
}

function main() {
  if (process.platform === "win32") {
    exportWindows();
  } else if (process.platform === "darwin") {
    exportMac();
  } else {
    throw new Error(`Portable releases are not supported on ${process.platform}.`);
  }
}

main();
