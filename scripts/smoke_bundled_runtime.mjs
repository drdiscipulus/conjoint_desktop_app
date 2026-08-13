import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const resourcesRoot = path.join(repoRoot, "src-tauri", "resources");
const shinyRoot = path.join(resourcesRoot, "shiny-app");
const library = path.join(resourcesRoot, "runtime", "R-library");

function runtimeLayout() {
  if (process.platform === "win32") {
    const rHome = path.join(resourcesRoot, "runtime", "R");
    return {
      rHome,
      executable: path.join(rHome, "bin", "Rscript.exe"),
      scriptArgs: (scriptPath) => [scriptPath]
    };
  }
  if (process.platform === "darwin") {
    const rHome = path.join(repoRoot, "src-tauri", "bundle-runtime", "R.framework", "Resources");
    return {
      rHome,
      executable: path.join(rHome, "bin", "exec", "R"),
      scriptArgs: (scriptPath) => ["--no-echo", "--no-restore", `--file=${scriptPath}`]
    };
  }
  throw new Error(`Bundled runtime smoke tests are not supported on ${process.platform}.`);
}

function main() {
  const { rHome, executable, scriptArgs } = runtimeLayout();
  const checkScript = path.join(shinyRoot, "scripts", "check_app.R");
  for (const requiredPath of [executable, library, checkScript]) {
    if (!existsSync(requiredPath)) {
      throw new Error(`Bundled runtime input is missing: ${requiredPath}`);
    }
  }

  execFileSync(executable, scriptArgs(checkScript), {
    cwd: shinyRoot,
    env: {
      ...process.env,
      R_HOME: rHome,
      R_LIBS_USER: library,
      CONJOINT_R_LIBRARY: library,
      RENV_CONFIG_AUTOLOADER_ENABLED: "FALSE"
    },
    stdio: "inherit"
  });
  console.log(`Bundled R runtime smoke test passed (${process.platform}-${process.arch}).`);
}

main();
