import { execFileSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const appPath = path.join(
  repoRoot,
  "src-tauri",
  "target",
  "release",
  "bundle",
  "macos",
  "Conjoint Companion.app"
);

function run(command, args, options = {}) {
  return execFileSync(command, args, {
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options
  }).trim();
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

function verifyNoSystemRReferences() {
  const offenders = [];
  for (const filePath of listFiles(appPath)) {
    let fileType = "";
    try {
      fileType = run("file", ["-b", filePath]);
    } catch {
      continue;
    }
    if (!fileType.includes("Mach-O")) {
      continue;
    }
    const dependencies = run("otool", ["-L", filePath]);
    if (dependencies.includes("/Library/Frameworks/R.framework")) {
      offenders.push(path.relative(appPath, filePath));
    }
    const architectures = run("lipo", ["-archs", filePath]);
    if (!architectures.split(/\s+/).includes("arm64")) {
      offenders.push(`${path.relative(appPath, filePath)} (missing arm64)`);
    }
  }
  if (offenders.length > 0) {
    throw new Error(`Invalid bundled native dependencies:\n${offenders.join("\n")}`);
  }
}

function verifyBundledR() {
  const rHome = path.join(appPath, "Contents", "Frameworks", "R.framework", "Resources");
  const rscript = path.join(rHome, "bin", "Rscript");
  if (!existsSync(rscript)) {
    throw new Error(`Bundled Rscript is missing at ${rscript}.`);
  }
  const library = path.join(appPath, "Contents", "Resources", "runtime", "R-library");
  const expression = [
    "required <- c('shiny', 'FrF2', 'DoE.base', 'psych', 'plotly', 'openxlsx')",
    "missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]",
    "if (length(missing)) stop(paste('Missing packages:', paste(missing, collapse = ', ')))",
    "cat(as.character(getRversion()))"
  ].join("; ");
  const version = run(rscript, ["-e", expression], {
    env: {
      ...process.env,
      R_HOME: rHome,
      R_LIBS_USER: library,
      CONJOINT_R_LIBRARY: library,
      RENV_CONFIG_AUTOLOADER_ENABLED: "FALSE"
    }
  });
  if (version !== "4.5.3") {
    throw new Error(`Bundled R reported ${version}, expected 4.5.3.`);
  }
}

function main() {
  if (process.platform !== "darwin" || process.arch !== "arm64") {
    throw new Error("macOS bundle verification must run on Apple Silicon.");
  }
  if (!existsSync(appPath)) {
    throw new Error(`macOS app bundle not found at ${appPath}.`);
  }
  verifyNoSystemRReferences();
  verifyBundledR();
  run("codesign", ["--verify", "--deep", "--strict", "--verbose=2", appPath]);
  run("spctl", ["--assess", "--type", "execute", "--verbose=2", appPath]);
  run("xcrun", ["stapler", "validate", appPath]);
  console.log(`Verified signed, notarized, self-contained app: ${appPath}`);
}

main();
