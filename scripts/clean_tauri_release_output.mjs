import { existsSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const releaseRoot = path.join(repoRoot, "src-tauri", "target", "release");
const generatedPaths = [
  path.join(releaseRoot, "resources"),
  path.join(releaseRoot, "bundle", "macos", "Conjoint Companion.app")
];

function removeGeneratedPath(target) {
  const resolved = path.resolve(target);
  const releasePrefix = releaseRoot + path.sep;
  if (!resolved.startsWith(releasePrefix)) {
    throw new Error(`Refusing to clean outside the Tauri release directory: ${resolved}`);
  }

  if (existsSync(resolved)) {
    rmSync(resolved, { recursive: true, force: true });
    console.log(`Removed stale Tauri release output: ${resolved}`);
  }
}

for (const generatedPath of generatedPaths) {
  removeGeneratedPath(generatedPath);
}
