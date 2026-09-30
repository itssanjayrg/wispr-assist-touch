# Security Policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's
[private vulnerability reporting](../../security/advisories/new) for this repository. Include the macOS
version, steps to reproduce, and the impact you foresee. You'll get an acknowledgement within a few days.

## Scope and threat model

Wispr Assist holds the macOS **Accessibility** permission, which is powerful. To keep the attack surface
small it: makes no network connections, runs with the hardened runtime, reads only the role, position and
editability of the focused element (never the text), ignores secure/password fields, and posts only three
synthetic key events (Fn, Return, ⌘⌫). Reports of anything that widens this (reading typed text, sending
other keys, writing outside its own preferences and optional log) are treated as high severity.
