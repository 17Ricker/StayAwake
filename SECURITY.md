# Security

StayAwake changes a system setting, so it needs administrator rights once. This page explains exactly what that means.

## What runs as administrator

Only two things, and only when you confirm them with your admin password in macOS's own dialog:

1. **Install the permission** (the first time you turn StayAwake on). A short script, run as root:
   - creates a temporary file with `mktemp` in `/tmp`;
   - writes the rule into it;
   - checks it with `visudo -cf`;
   - installs it with `install -m 440 -o root -g wheel` into `/etc/sudoers.d/stayawake-uid<your user ID>`;
   - if the single file used by early builds, `/etc/sudoers.d/stayawake`, contains exactly your old rule, removes it.
2. **Remove the permission** (Settings → Remove permission): deletes your file and, if it's yours, the early-build one.

Rules for everything that runs as root:

- It touches nothing outside its own temporary file in `/tmp` and `/etc/sudoers.d/`.
- It uses only absolute paths (`/usr/bin/…`, `/bin/…`), so it doesn't depend on `PATH`.
- No user-controlled text goes into the sudoers rule. The rule uses only your numeric user ID, and your user name is used solely to check and remove the early-build file if it contains letters, digits, `.`, `_` or `-`.

The code is in [`Sources/Permission.swift`](Sources/Permission.swift). The tests in [`Tests/PermissionTests.swift`](Tests/PermissionTests.swift) run these scripts without root, in a temporary folder.

## What the permission allows

```
#<your user ID> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

Your user, and any app running as your user, can turn system sleep on or off without a password. Nothing else: no other command, no other arguments, no other user.

## What StayAwake doesn't do

- No network connections, no telemetry, no automatic updates.
- It never sees or stores your password: macOS asks for it.
- No installer script piped to a shell. Releases are built by GitHub Actions from this repository, with a SHA-256 file and a [build provenance attestation](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations).

## Supported versions

| Version | Supported |
|---|---|
| 1.x | ✅ |
| before 1.0 | ❌ (please update) |

## Reporting a vulnerability

Please **don't open a public issue**. Use GitHub's private reporting: **Security** tab → **Report a vulnerability**. Include what you found, how to reproduce it, and the macOS version. You'll get an answer as soon as possible.
