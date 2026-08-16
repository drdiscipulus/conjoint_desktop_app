# Changelog

All notable changes to Conjoint Companion Desktop are documented here.

## Unreleased

- Restrict macOS notarization to credentials stored in the login keychain.
- Stop forwarding Apple release variables to unrelated build and test processes.
- Remove the library-validation exception from the hardened macOS runtime.
- Align embedded maintenance, privacy, and regression documentation with the desktop distribution.

## 1.0.0 - 2026-08-14

- Correct test-retest pairing by respondent and profile, independent of row order.
- Add explicit handling and reporting for partial profile replication and incomplete respondents.
- Make the embedded Shiny application the authoritative desktop source.
- Provide portable offline releases for Windows x64 and Apple Silicon macOS.
- Sign and notarize the macOS application with Apple Developer ID.
- Harden the desktop shell, dependency checks, and automated tests.
- Add citation metadata, user documentation, issue templates, and checksum-verified release archives.
