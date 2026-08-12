import { execFileSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const localEnvPath = path.join(repoRoot, ".env.release.local");
const appPath = path.join(
  repoRoot,
  "src-tauri",
  "target",
  "release",
  "bundle",
  "macos",
  "Conjoint Companion.app"
);
const frameworkPath = path.join(appPath, "Contents", "Frameworks", "R.framework");
const entitlementsPath = path.join(repoRoot, "src-tauri", "Entitlements.plist");

function parseEnvLine(line) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith("#")) {
    return null;
  }

  const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
  if (!match) {
    throw new Error(`Invalid .env.release.local line: ${line}`);
  }

  let value = match[2].trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  return [match[1], value];
}

function loadLocalEnv() {
  if (!existsSync(localEnvPath)) {
    return {};
  }
  return Object.fromEntries(
    readFileSync(localEnvPath, "utf-8")
      .split(/\r?\n/)
      .map(parseEnvLine)
      .filter(Boolean)
  );
}

// Explicit shell variables take precedence over values in the ignored file.
const releaseEnv = { ...loadLocalEnv(), ...process.env };

function signingOnlyEnv() {
  const nextEnv = { ...releaseEnv };
  for (const name of [
    "APPLE_ID",
    "APPLE_PASSWORD",
    "APPLE_TEAM_ID",
    "APPLE_API_ISSUER",
    "APPLE_API_KEY",
    "APPLE_API_KEY_PATH"
  ]) {
    delete nextEnv[name];
  }
  return nextEnv;
}

function run(command, args, options = {}) {
  execFileSync(command, args, {
    cwd: repoRoot,
    env: releaseEnv,
    stdio: "inherit",
    ...options
  });
}

function runNpmScript(scriptName) {
  run("npm", ["run", scriptName]);
}

function listFiles(root) {
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
  walk(root);
  return files;
}

function isMachO(filePath) {
  try {
    return execFileSync("file", ["-b", filePath], { encoding: "utf-8" }).includes("Mach-O");
  } catch {
    return false;
  }
}

function signNativePath(targetPath) {
  run("codesign", [
    "--force",
    "--options",
    "runtime",
    "--timestamp",
    "--sign",
    releaseEnv.APPLE_SIGNING_IDENTITY,
    targetPath
  ]);
}

function signBundledNativeCode() {
  if (!existsSync(appPath) || !existsSync(frameworkPath)) {
    throw new Error(`Complete macOS app bundle not found at ${appPath}.`);
  }

  // Sign deepest nested code first, then its enclosing framework and app.
  const nativeFiles = listFiles(appPath)
    .filter(isMachO)
    .sort((left, right) => right.split(path.sep).length - left.split(path.sep).length);
  for (const filePath of nativeFiles) {
    signNativePath(filePath);
  }
  signNativePath(frameworkPath);

  run("codesign", [
    "--force",
    "--deep",
    "--options",
    "runtime",
    "--timestamp",
    "--entitlements",
    entitlementsPath,
    "--sign",
    releaseEnv.APPLE_SIGNING_IDENTITY,
    appPath
  ]);
  run("codesign", ["--verify", "--deep", "--strict", "--verbose=2", appPath]);
}

function notarizationArgs(archivePath) {
  if (releaseEnv.APPLE_ID && releaseEnv.APPLE_PASSWORD && releaseEnv.APPLE_TEAM_ID) {
    return [
      "notarytool",
      "submit",
      archivePath,
      "--apple-id",
      releaseEnv.APPLE_ID,
      "--password",
      releaseEnv.APPLE_PASSWORD,
      "--team-id",
      releaseEnv.APPLE_TEAM_ID,
      "--wait"
    ];
  }
  return [
    "notarytool",
    "submit",
    archivePath,
    "--key",
    releaseEnv.APPLE_API_KEY_PATH,
    "--key-id",
    releaseEnv.APPLE_API_KEY,
    "--issuer",
    releaseEnv.APPLE_API_ISSUER,
    "--wait"
  ];
}

function notarizeAndStaple() {
  const tempRoot = mkdtempSync(path.join(os.tmpdir(), "conjoint-macos-notary-"));
  try {
    const tempApp = path.join(tempRoot, "Conjoint Companion.app");
    const archivePath = path.join(tempRoot, "Conjoint Companion.zip");
    cpSync(appPath, tempApp, { recursive: true, verbatimSymlinks: true });
    run(
      "ditto",
      ["-c", "-k", "--sequesterRsrc", "--keepParent", path.basename(tempApp), archivePath],
      { cwd: tempRoot }
    );
    run("xcrun", notarizationArgs(archivePath));
    run("xcrun", ["stapler", "staple", appPath]);
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
}

function appSize() {
  return listFiles(appPath).reduce((bytes, filePath) => bytes + statSync(filePath).size, 0);
}

function main() {
  run(process.execPath, ["scripts/release_preflight.mjs", "macos"]);
  runNpmScript("check");
  runNpmScript("prepare:runtime");
  runNpmScript("smoke:runtime");
  run(
    "npx",
    ["tauri", "build", "--bundles", "app", "--config", "src-tauri/tauri.macos.conf.json"],
    { env: signingOnlyEnv() }
  );
  signBundledNativeCode();
  notarizeAndStaple();
  run(process.execPath, ["scripts/verify_macos_bundle.mjs"]);
  runNpmScript("export:portable");
  console.log(`Signed and notarized app bundle: ${appPath}`);
  console.log(`App bundle bytes: ${appSize()}`);
}

main();
