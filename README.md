# BREACH PROTOCOL — iOS Native Edition

A SwiftUI narrative terminal puzzle game for iPhone. The terminal and network are fictional; all commands are simulated locally and the game does not connect to external systems.

## First playable build

- Dark terminal UI with cyan accents
- Fictional commands: `help`, `status`, `files list`, `files read`, `logs search`, `evidence`, `decode`, `clear`, and `restart`
- Chapter 01 investigation, clue collection, and a cipher conclusion
- Local progress save
- iPhone portrait layout

## Build with GitHub Actions

1. Open the **Actions** tab.
2. Select **Build BREACH PROTOCOL iOS**.
3. Choose **Run workflow**, or push a commit to `main`.
4. Download the `breach-protocol-ios-unsigned` artifact after a successful run.

The workflow produces an unsigned app and IPA. **An unsigned IPA is not directly installable on a normal iPhone.** Installation requires a suitable signing and provisioning method. This repository does not include signing certificates or secrets.

## Project layout

- `BreachProtocol/BreachProtocolApp.swift` — app entry point
- `BreachProtocol/ContentView.swift` — terminal UI, commands, chapter logic, and save state
- `project.yml` — XcodeGen project definition
- `.github/workflows/ios-build.yml` — GitHub Actions build workflow

This is the first playable prototype. Chapter 02, expanded story branches, and signed installation are not implemented yet.
