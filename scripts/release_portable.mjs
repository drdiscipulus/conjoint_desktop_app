import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function runNpmScript(scriptName) {
  execFileSync("npm", ["run", scriptName], {
    cwd: repoRoot,
    stdio: "inherit",
    shell: process.platform === "win32"
  });
}

if (process.platform === "darwin") {
  runNpmScript("release:portable:macos");
} else if (process.platform === "win32") {
  runNpmScript("release:portable:windows");
} else {
  runNpmScript("tauri:build");
  runNpmScript("export:portable");
}
