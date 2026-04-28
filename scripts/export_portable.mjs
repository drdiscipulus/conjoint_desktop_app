import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const releaseRoot = path.join(repoRoot, "src-tauri", "target", "release");
const artifactsRoot = path.join(repoRoot, "release-artifacts", process.platform, "portable");
const executableName = process.platform === "win32"
  ? "conjoint_companion_desktop.exe"
  : "conjoint_companion_desktop";

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

function main() {
  const executablePath = path.join(releaseRoot, executableName);
  if (!existsSync(executablePath)) {
    throw new Error(`Release executable not found at ${executablePath}. Run npm run tauri:build first.`);
  }

  removeAndCreate(artifactsRoot);
  cpSync(executablePath, path.join(artifactsRoot, executableName), { force: true });
  copyIfPresent(path.join(releaseRoot, "resources"), path.join(artifactsRoot, "resources"));

  writeFileSync(path.join(artifactsRoot, ".conjoint_companion_portable"), "", "utf-8");
  const summary = summarize(artifactsRoot);
  console.log(`Portable artifact exported to ${artifactsRoot}`);
  console.log(`Files: ${summary.fileCount}`);
}

main();
