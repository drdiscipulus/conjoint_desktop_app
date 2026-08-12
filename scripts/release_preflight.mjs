import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const requestedPlatform = process.argv[2];
const expectedRVersion = "4.5.3";

function run(command, args) {
  return execFileSync(command, args, {
    cwd: repoRoot,
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"]
  }).trim();
}

function requireCleanWorktree() {
  const status = run("git", ["status", "--porcelain"]);
  if (status) {
    throw new Error("Release builds require a clean Git worktree.");
  }
}

function readVersions() {
  const packageVersion = JSON.parse(readFileSync(path.join(repoRoot, "package.json"), "utf-8")).version;
  const tauriVersion = JSON.parse(
    readFileSync(path.join(repoRoot, "src-tauri", "tauri.conf.json"), "utf-8")
  ).version;
  const cargoSource = readFileSync(path.join(repoRoot, "src-tauri", "Cargo.toml"), "utf-8");
  const cargoVersion = cargoSource.match(/^version = "([^"]+)"/m)?.[1];
  const citationSource = readFileSync(path.join(repoRoot, "CITATION.cff"), "utf-8");
  const citationVersion = citationSource.match(/^version: "([^"]+)"/m)?.[1];

  const versions = [packageVersion, tauriVersion, cargoVersion, citationVersion];
  if (versions.some((version) => !version) || new Set(versions).size !== 1) {
    throw new Error(`Release versions do not match: ${versions.join(", ")}`);
  }
  return packageVersion;
}

function checkR() {
  const version = run("Rscript", ["-e", "cat(as.character(getRversion()))"]);
  if (version !== expectedRVersion) {
    throw new Error(`Release builds require R ${expectedRVersion}; found ${version}.`);
  }
}

function checkPlatform() {
  if (requestedPlatform === "windows" && (process.platform !== "win32" || process.arch !== "x64")) {
    throw new Error(`Windows releases require win32-x64; found ${process.platform}-${process.arch}.`);
  }
  if (requestedPlatform === "macos" && (process.platform !== "darwin" || process.arch !== "arm64")) {
    throw new Error(`macOS releases require darwin-arm64; found ${process.platform}-${process.arch}.`);
  }
  if (!new Set(["windows", "macos"]).has(requestedPlatform)) {
    throw new Error("Usage: node scripts/release_preflight.mjs <windows|macos>");
  }
}

function checkMacSigning() {
  if (requestedPlatform !== "macos") {
    return;
  }
  for (const variable of ["APPLE_SIGNING_IDENTITY", "APPLE_ID", "APPLE_PASSWORD", "APPLE_TEAM_ID"]) {
    if (!process.env[variable]) {
      throw new Error(`${variable} must be set for a signed and notarized macOS release.`);
    }
  }
  const identities = run("security", ["find-identity", "-v", "-p", "codesigning"]);
  if (!identities.includes(process.env.APPLE_SIGNING_IDENTITY)) {
    throw new Error("APPLE_SIGNING_IDENTITY is not available in the macOS keychain.");
  }
}

function main() {
  checkPlatform();
  requireCleanWorktree();
  const version = readVersions();
  checkR();
  checkMacSigning();
  console.log(`Release preflight passed for Conjoint Companion ${version} (${requestedPlatform}).`);
}

main();
