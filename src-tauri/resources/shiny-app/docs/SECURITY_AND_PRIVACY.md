# Security And Privacy Notes

This app is intended as a public-facing research service. Unknown users may
upload files, so upload handling is intentionally conservative.

## Accepted Uploads

- Accepted file extensions: `.csv`, `.xlsx`
- Maximum upload size: 5 MB
- Maximum rows: 25,000
- Maximum columns: 250
- XLSX uploads must contain exactly one worksheet.
- Required reliability columns: `respondent`, `round`, `profile`, `dv`, and at
  least two `att_` columns.

Browser MIME types are not trusted as the only validation signal. The server
checks extension, file existence, file size, parseability, dimensions, required
columns, numeric coercion, and expected `round` values.

## Temporary Files

Shiny stores raw uploads in its own temporary upload location. This app creates
an additional session-specific directory under:

```text
tempdir()/conjoint_trt_app/<session-token>
```

Generated result files are written there before being handed to Shiny's download
mechanism.

## Cleanup

The app registers `session$onSessionEnded()` cleanup for the session directory.
The reset button also removes generated session files and recreates an empty
session directory for continued use.

## What Is Not Stored

The app does not intentionally persist:

- uploaded research datasets,
- participant/respondent-level source data,
- generated result exports after session cleanup,
- analytics or tracking data.

User-provided filenames are sanitized for display/format checks and are not used
as internal output paths.

## Operator Responsibilities

For internet-facing deployment, server configuration remains important:

- Serve the app over HTTPS.
- Put Shiny behind a maintained reverse proxy where appropriate.
- Review reverse-proxy, system, and Shiny Server logs; the app avoids logging
  raw uploaded data, but infrastructure logs are outside app control.
- Keep R, Shiny, system packages, and server dependencies patched.
- Consider OS/container-level resource limits for CPU, memory, and process
  lifetime if the server accepts public traffic.
