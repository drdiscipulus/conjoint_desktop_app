import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const packageJson = JSON.parse(readFileSync(path.join(repoRoot, "package.json"), "utf-8"));
const tauriConfig = JSON.parse(readFileSync(path.join(repoRoot, "src-tauri", "tauri.conf.json"), "utf-8"));
const releaseRoot = path.join(repoRoot, "src-tauri", "target", "release");
const artifactsRoot = path.join(repoRoot, "release-artifacts", process.platform, "portable");
const stagingRoot = path.join(artifactsRoot, "staging");
const executableName = process.platform === "win32"
  ? "conjoint_companion_desktop.exe"
  : "conjoint_companion_desktop";
const productName = tauriConfig.productName || "Conjoint Companion";

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
    cpSync(source, destination, { recursive: true, force: true });
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
  execFileSync("powershell.exe", [
    "-NoProfile",
    "-Command",
    "& { param($source, $destination) Compress-Archive -Path $source -DestinationPath $destination -Force }",
    path.join(sourceDirectory, "*"),
    archivePath
  ], { stdio: "inherit" });
}

function createTarGz(sourceDirectory, archivePath) {
  execFileSync("tar", [
    "-czf",
    archivePath,
    "-C",
    path.dirname(sourceDirectory),
    path.basename(sourceDirectory)
  ], { stdio: "inherit" });
}

function createMacZip(sourceDirectory, archivePath) {
  execFileSync("ditto", [
    "-c",
    "-k",
    "--sequesterRsrc",
    "--keepParent",
    path.basename(sourceDirectory),
    archivePath
  ], {
    cwd: path.dirname(sourceDirectory),
    stdio: "inherit"
  });
}

function verifyMacApp(appPath) {
  if (process.env.CONJOINT_SKIP_MACOS_GATEKEEPER_CHECK === "1") {
    console.warn("Skipping macOS Gatekeeper verification because CONJOINT_SKIP_MACOS_GATEKEEPER_CHECK=1.");
    return;
  }

  execFileSync("codesign", [
    "--verify",
    "--deep",
    "--strict",
    "--verbose=2",
    appPath
  ], { stdio: "inherit" });
  execFileSync("xcrun", [
    "stapler",
    "validate",
    appPath
  ], { stdio: "inherit" });
  execFileSync("spctl", [
    "--assess",
    "--type",
    "execute",
    "--verbose=4",
    appPath
  ], { stdio: "inherit" });
}

function writeChecksum(archivePath, archiveName) {
  const digest = sha256(archivePath);
  writeFileSync(path.join(artifactsRoot, "SHA256SUMS.txt"), `${digest}  ${archiveName}\n`, "utf-8");
}

function exportMacPortable(artifactBaseName) {
  const appBundle = path.join(releaseRoot, "bundle", "macos", `${productName}.app`);
  if (!existsSync(appBundle)) {
    throw new Error(`macOS app bundle not found at ${appBundle}. Run npm run tauri:build:macos first.`);
  }

  removeAndCreate(artifactsRoot);
  const portableRoot = path.join(stagingRoot, artifactBaseName);
  mkdirSync(portableRoot, { recursive: true });

  const stagedApp = path.join(portableRoot, `${productName}.app`);
  cpSync(appBundle, stagedApp, { recursive: true, force: true });
  writeFileSync(path.join(portableRoot, ".conjoint_companion_portable"), "", "utf-8");

  verifyMacApp(stagedApp);

  const archiveName = `${artifactBaseName}.zip`;
  const archivePath = path.join(artifactsRoot, archiveName);
  createMacZip(portableRoot, archivePath);
  writeChecksum(archivePath, archiveName);

  const summary = summarize(portableRoot);
  console.log(`Portable staging directory: ${portableRoot}`);
  console.log(`Release archive: ${archivePath}`);
  console.log(`Checksum file: ${path.join(artifactsRoot, "SHA256SUMS.txt")}`);
  console.log(`Files: ${summary.fileCount}`);
}

function exportExecutablePortable(artifactBaseName) {
  const executablePath = path.join(releaseRoot, executableName);
  if (!existsSync(executablePath)) {
    throw new Error(`Release executable not found at ${executablePath}. Run npm run tauri:build first.`);
  }

  removeAndCreate(artifactsRoot);
  const portableRoot = path.join(stagingRoot, artifactBaseName);
  mkdirSync(portableRoot, { recursive: true });

  cpSync(executablePath, path.join(portableRoot, executableName), { force: true });
  copyIfPresent(path.join(releaseRoot, "resources"), path.join(portableRoot, "resources"));
  writeFileSync(path.join(portableRoot, ".conjoint_companion_portable"), "", "utf-8");

  const archiveName = process.platform === "win32"
    ? `${artifactBaseName}.zip`
    : `${artifactBaseName}.tar.gz`;
  const archivePath = path.join(artifactsRoot, archiveName);

  if (process.platform === "win32") {
    createWindowsZip(portableRoot, archivePath);
  } else {
    createTarGz(portableRoot, archivePath);
  }

  writeChecksum(archivePath, archiveName);

  const summary = summarize(portableRoot);
  console.log(`Portable staging directory: ${portableRoot}`);
  console.log(`Release archive: ${archivePath}`);
  console.log(`Checksum file: ${path.join(artifactsRoot, "SHA256SUMS.txt")}`);
  console.log(`Files: ${summary.fileCount}`);
}

function main() {
  const artifactBaseName = `Conjoint-Companion-v${packageJson.version}-${platformLabel()}`;
  if (process.platform === "darwin") {
    exportMacPortable(artifactBaseName);
  } else {
    exportExecutablePortable(artifactBaseName);
  }
}

main();
