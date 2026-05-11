# CLAUDE.md — Barik Enhanced

## Project memory in the LLM wiki

**Wiki path:**
```
~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Obsidian/llm-wiki/docs/wiki/barik/
```

**Read order:** `README.md` → `gotchas.md` → `release.md`.

## Update the wiki when you learn something worth remembering
Non-obvious constraints, workarounds, decisions, footguns → write back and bump `updated:`.

## Critical rules
1. **Two repos must move together** — this app + `homebrew-barik-enhanced` cask. A release without bumping the cask is incomplete.
2. **Version 1.2.9 = rollback to 1.2.6 functionality** — don't trust version numbers blindly; read CHANGELOG.
3. **macOS 14.0+ only.** SwiftUI APIs require Sonoma or later.
4. **Notarization required** for distribution outside the App Store.
5. **Homebrew cask sha256 must match** the actually-released artifact (most common release bug).
6. **Don't regress performance** — the fork's identity is "performance optimizations" over upstream Barik.

## Quick orientation
Swift + SwiftUI macOS menu bar app. Fork of `mocki-toki/barik`. Distributed via GitHub Releases + Homebrew tap.

## Style
Wiki conventions: `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Obsidian/llm-wiki/CLAUDE.md`.
