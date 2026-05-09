import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const tauriConfig = JSON.parse(
  readFileSync(path.join(repoRoot, "src-tauri", "tauri.conf.json"), "utf-8")
);

function notarizationCredentialMode() {
  const apiKeyMode = ["APPLE_API_ISSUER", "APPLE_API_KEY", "APPLE_API_KEY_PATH"].every(
    (name) => Boolean(process.env[name])
  );
  const appleIdMode = ["APPLE_ID", "APPLE_PASSWORD", "APPLE_TEAM_ID"].every(
    (name) => Boolean(process.env[name])
  );

  if (apiKeyMode) {
    return "App Store Connect API key";
  }
  if (appleIdMode) {
    return "Apple ID app-specific password";
  }

  throw new Error(
    "Missing notarization credentials. Provide either APPLE_API_ISSUER, APPLE_API_KEY, APPLE_API_KEY_PATH " +
      "or APPLE_ID, APPLE_PASSWORD, APPLE_TEAM_ID."
  );
}

function configuredSigningIdentity() {
  return (
    process.env.APPLE_SIGNING_IDENTITY ||
    tauriConfig.bundle?.macOS?.signingIdentity ||
    ""
  );
}

function verifyLocalIdentity(identity) {
  if (process.env.APPLE_CERTIFICATE && process.env.APPLE_CERTIFICATE_PASSWORD) {
    return "certificate supplied through APPLE_CERTIFICATE";
  }

  const identities = execFileSync("security", ["find-identity", "-v", "-p", "codesigning"], {
    cwd: repoRoot,
    encoding: "utf-8"
  });
  const match = identities
    .split(/\r?\n/)
    .find((line) => line.includes(identity) || line.includes(`"${identity}"`));

  if (!match) {
    throw new Error(
      `Signing identity was not found in the local keychain: ${identity}\n` +
        "Run: security find-identity -v -p codesigning"
    );
  }
  if (!match.includes("Developer ID Application")) {
    throw new Error(
      `The configured identity is not a Developer ID Application certificate:\n${match}`
    );
  }

  return match.trim();
}

function main() {
  if (process.platform !== "darwin") {
    console.log("macOS notarization check skipped on this platform.");
    return;
  }

  const identity = configuredSigningIdentity();
  if (!identity) {
    throw new Error(
      "Missing signing identity. Set APPLE_SIGNING_IDENTITY or configure bundle.macOS.signingIdentity."
    );
  }
  const credentialMode = notarizationCredentialMode();
  const identitySummary = verifyLocalIdentity(identity);

  console.log(`macOS signing identity: ${identitySummary}`);
  console.log(`macOS notarization credentials: ${credentialMode}`);
}

main();
