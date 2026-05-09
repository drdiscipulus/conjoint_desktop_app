import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const localEnvPath = path.join(repoRoot, ".env.release.local");
const appPath = path.join(repoRoot, "src-tauri", "target", "release", "bundle", "macos", "Conjoint Companion.app");
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

const env = {
  ...process.env,
  ...loadLocalEnv()
};

function signingOnlyEnv() {
  const nextEnv = { ...env };
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

function runNpmScript(scriptName) {
  execFileSync("npm", ["run", scriptName], {
    cwd: repoRoot,
    env,
    stdio: "inherit"
  });
}

function runCommand(command, args, options = {}) {
  execFileSync(command, args, {
    cwd: repoRoot,
    env,
    stdio: "inherit",
    ...options
  });
}

function walkFiles(root) {
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

function signPath(targetPath) {
  runCommand("codesign", [
    "--force",
    "--options",
    "runtime",
    "--timestamp",
    "--entitlements",
    entitlementsPath,
    "--sign",
    env.APPLE_SIGNING_IDENTITY,
    targetPath
  ]);
}

function signBundledNativeCode() {
  if (!existsSync(appPath)) {
    throw new Error(`macOS app bundle not found at ${appPath}`);
  }

  const files = walkFiles(appPath).filter(isMachO);
  for (const filePath of files) {
    signPath(filePath);
  }

  runCommand("codesign", [
    "--force",
    "--deep",
    "--options",
    "runtime",
    "--timestamp",
    "--entitlements",
    entitlementsPath,
    "--sign",
    env.APPLE_SIGNING_IDENTITY,
    appPath
  ]);
  runCommand("codesign", ["--verify", "--deep", "--strict", "--verbose=2", appPath]);
}

function notarizationArgs(archivePath) {
  if (env.APPLE_ID && env.APPLE_PASSWORD && env.APPLE_TEAM_ID) {
    return [
      "notarytool",
      "submit",
      archivePath,
      "--apple-id",
      env.APPLE_ID,
      "--password",
      env.APPLE_PASSWORD,
      "--team-id",
      env.APPLE_TEAM_ID,
      "--wait"
    ];
  }

  if (env.APPLE_API_ISSUER && env.APPLE_API_KEY && env.APPLE_API_KEY_PATH) {
    return [
      "notarytool",
      "submit",
      archivePath,
      "--key",
      env.APPLE_API_KEY_PATH,
      "--key-id",
      env.APPLE_API_KEY,
      "--issuer",
      env.APPLE_API_ISSUER,
      "--wait"
    ];
  }

  throw new Error("Missing Apple notarization credentials.");
}

function notarizeAndStaple() {
  const tempRoot = mkdtempSync(path.join(os.tmpdir(), "conjoint-macos-notary-"));
  const tempApp = path.join(tempRoot, "Conjoint Companion.app");
  const archivePath = path.join(tempRoot, "Conjoint Companion.zip");

  cpSync(appPath, tempApp, { recursive: true });
  runCommand("ditto", [
    "-c",
    "-k",
    "--sequesterRsrc",
    "--keepParent",
    path.basename(tempApp),
    archivePath
  ], { cwd: tempRoot });

  runCommand("xcrun", notarizationArgs(archivePath));
  runCommand("xcrun", ["stapler", "staple", appPath]);
  runCommand("xcrun", ["stapler", "validate", appPath]);
  rmSync(tempRoot, { recursive: true, force: true });
}

function appSize() {
  let bytes = 0;
  for (const filePath of walkFiles(appPath)) {
    bytes += statSync(filePath).size;
  }
  return bytes;
}

function buildMacApp() {
  runNpmScript("check:macos-notarization");
  runNpmScript("prepare:runtime");
  runCommand("npx", ["tauri", "build", "--bundles", "app"], { env: signingOnlyEnv() });
  signBundledNativeCode();
  notarizeAndStaple();
  console.log(`Signed and notarized app bundle: ${appPath}`);
  console.log(`App bundle bytes: ${appSize()}`);
}

buildMacApp();

if (!process.argv.includes("--build-only")) {
  runNpmScript("export:portable");
}
