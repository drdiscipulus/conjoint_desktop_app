# Security And Privacy Notes

This document describes the Shiny application as bundled in Conjoint Companion
Desktop. The separately hosted web app has its own deployment and server
security responsibilities.

## Desktop Security Boundary

The Tauri shell starts the bundled R and Shiny process on `127.0.0.1` using an
available port selected for the current session. The desktop window accepts
navigation and downloads only from that exact local endpoint. External web pages
do not receive desktop capabilities.

The downloaded application works offline. It does not send uploaded research
data to GitHub, the hosted Shiny app, analytics services, or another remote
service.

## Accepted Uploads

- Accepted file extensions: `.csv`, `.xlsx`
- Maximum upload size: 5 MB
- Maximum rows: 25,000
- Maximum columns: 250
- XLSX uploads must contain exactly one worksheet.
- Required reliability columns: `respondent`, `round`, `profile`, `dv`, and at
  least two `att_` columns.

Browser MIME types are not trusted as the only validation signal. The local
Shiny process checks extension, file existence, file size, parseability,
dimensions, required columns, numeric coercion, expected `round` values,
non-empty identifiers, duplicate respondent/round/profile keys, and consistent
profile attributes.

Only profiles present in both rounds are analyzed. A respondent missing any
observation within that common profile set is removed from all analyzed profiles
and both rounds. The UI reports profile and respondent exclusions before the
analysis runs.

## Temporary Files And Downloads

Shiny stores raw uploads in its temporary upload location. The app creates an
additional session-specific directory under:

```text
tempdir()/conjoint_trt_app/<session-token>
```

Generated result files are written there before being handed to the desktop
download mechanism. Completed downloads are copied to the user's normal
Downloads directory after its writeability has been checked. Existing files are
not overwritten; the app chooses a unique filename instead.

The app registers `session$onSessionEnded()` cleanup for the session directory.
The reset button also removes generated session files and recreates an empty
session directory for continued use. Closing the desktop window stops the local
R child process.

## What Is Not Persisted

The app does not intentionally persist:

- uploaded research datasets;
- participant/respondent-level source data;
- generated temporary exports after session cleanup;
- analytics or tracking data.

Files that the user explicitly downloads remain in the normal Downloads folder.
User-provided filenames are sanitized for display and format checks and are not
used as internal output paths.

## Release Hardening

Release archives contain the application source, the platform-specific R
runtime, and a locked R package library. They do not contain release
credentials.

macOS releases use hardened runtime, retain library validation, and are signed
and notarized with credentials stored in the macOS login keychain. Windows
portable releases are currently unsigned; users should download them only from
the official GitHub Releases page and verify the published SHA-256 checksum.
