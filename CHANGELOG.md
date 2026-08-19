# Changelog

## 1.6.0 - 2026-08-19

### New Features
- **WireGuard widget**: Add `default.wireguard` with native macOS tunnel-state detection, a compact health indicator, and a detailed gateway/peer reachability popup.
- **Safe health checks**: Run bounded ICMP probes off the main thread, prevent overlapping refreshes, and clearly distinguish reachability from authoritative WireGuard handshakes.

### Bug Fixes
- **Duplicate widget layout IDs**: Give repeated widgets such as dividers stable per-instance identities so SwiftUI no longer reports duplicate-ID layout faults.

## 1.5.0 - 2026-07-30

### New Features
- **Clipboard widget**: Add `default.clipboard`, a bounded text history that exists only in memory while Barik Enhanced runs. Its compact preview and popup limits are configurable, and copied content is never persisted or transmitted.

### Improvements
- **Meetings widget**: Replace the split direct-join/calendar controls with one clean schedule-opening target. Join remains available from validated event rows in the full Today/Tomorrow popup.

## 1.4.0

### New Features
- **Meetings widget**: Add a standalone `default.meetings` widget powered by calendars already synchronized with macOS. It shows the active or next Google Meet, Zoom, or Microsoft Teams event, opens its validated meeting URL with one click, and provides a separate Today/Tomorrow schedule with safe empty, linkless, and calendar-permission states.

### Privacy
- Meeting titles, locations, notes, URLs, and schedule data are processed locally through EventKit and are not persisted or sent to a new service.

## 1.3.8

### Bug Fixes
- **Claude Usage widget: duplicate background requests**: Wake and session notifications are now coalesced into one usage fetch, preventing simultaneous API requests and retry delays.

## 1.3.7

### Bug Fixes
- **Codex Usage widget: excessive CPU use**: Refreshes now coalesce overlapping scans and read only the latest 20 session transcripts, using the final 512 KB of each transcript. This avoids repeatedly parsing the full Codex history, which can contain very large JSONL session files.

## 1.3.6

### Improvements
- **Pinned right-side layout**: Widgets after the first spacer/divider are now in an independent ZStack layer anchored to the right edge — they never shift when left-side content (e.g. AeroSpace window titles) changes width. Left-side widgets are clipped instead of pushing the right side.
- **Spaces widget: smart title truncation**: Focused window titles auto-trim to 20 characters when a space has more than 3 windows (instead of the default 50), keeping spaces compact.
- **Vertical centering**: Both ZStack layers fill the full bar height so widgets are vertically centered.

## 1.3.5

### Improvements
- **Subtle full-screen background blur**: Reverted to the upstream Barik blur style — full-screen `Material` blur with no rounded corners, shadows, or strokes. Configurable via `blur` (1–6 intensity, 7 = black).
- **NSPanel transparency fix**: The background and menu bar panels now set `isOpaque = false` with layer-backed hosting views, ensuring `Material` blur composites correctly.

### Bug Fixes
- **Claude Usage widget: repeated keychain password prompts**: The Claude Usage widget read Claude Code's keychain item (`Claude Code-credentials`) on every refresh — the 60-second timer plus a burst on every wake/screen-wake — which popped the macOS "Barik Enhanced wants to access key" dialog over and over. ("Always Allow" never stuck because Claude Code resets that item's access list whenever it refreshes its own OAuth token.) The widget now caches the token in memory and reuses it until it actually expires, so background refreshes never touch the keychain. The keychain is only read on first connect, when you press "Allow Access", or once the token has expired.

## 1.3.3

### Bug Fixes
- **Time + settings gear hidden on narrow displays**: After 1.3.2 made the bar edge-to-edge by default, the rightmost widgets (clock and settings cog) were drawn underneath the native macOS status icons on narrow screens (e.g., 16" MacBook at "Larger Text" scaling). Wide-screen layouts are unchanged. Narrow displays (effective width under 1500pt) now automatically reserve enough trailing space to keep the time and gear visible. Override with `experimental.foreground.system-status-reservation` in your config (set to `0` to force edge-to-edge).

### Improvements
- **Time widget margin**: Added a small leading gap before the time so it doesn't sit flush against the preceding widget.

## 1.3.2

### Improvements
- **Full-width menu bar**: The bar now extends edge-to-edge by default. The fixed 220pt trailing reservation introduced in 1.3.1 (to avoid Hidden Bar / Bartender jitter) is gone — set `experimental.foreground.horizontalPadding` in your config if you still want a cushion before the native status area.
- **Universal binary**: Now shipped as a universal app (arm64 + x86_64). Apple Silicon Macs run the native slice instead of going through Rosetta.

### Bug Fixes
- **Homebrew install name**: The built app is now natively produced as `BarikEnhanced.app` (matching the Homebrew cask), instead of `Barik.app` that brew had to rename on install. Bundle identifier (`com.mateocerquetella.BarikEnhanced`) is unchanged, so existing installs upgrade in place.
- **Display name**: Corrected `CFBundleDisplayName` from the accidental "BarikEnhanced Enhanced" introduced during the project rename back to "Barik Enhanced".

### Internal
- Renamed the source tree, Xcode project, scheme, and entitlements from `Barik` → `BarikEnhanced` to match the distributed product name. No functional changes.

## 1.3.1

### Bug Fixes
- **Layout jitter with Hidden Bar / Bartender**: Stopped reacting to changes in the native status-area width. Toggling utilities like Hidden Bar no longer causes Barik's trailing widgets (clock, gear) to shift. The trailing reservation is now a fixed conservative width — adjust `experimental.foreground.horizontalPadding` in your config if you need more space.

## 1.3.0

### New Features
- **OpenCode Usage widget**: Track OpenCode Go subscription usage from the menu bar. Outer ring shows the rolling 5-hour window, inner ring shows the weekly window, and the terminal icon drains to indicate monthly remaining. Numbers come from the local opencode message database (`~/.local/share/opencode/opencode.db`); a one-tap link in the popup opens the official dashboard at `opencode.ai/auth` for the authoritative numbers — opencode does not yet expose a public usage API ([feature request #16017](https://github.com/anomalyco/opencode/issues/16017)).

### Improvements
- **Codex Usage widget**: Now surfaces both the primary and secondary rate-limit windows when the latest session snapshot reports them, mirroring how the Codex CLI reports usage.

## 1.2.9

### Bug Fixes
- Restored the application codebase to the stable `1.2.6` implementation while releasing it as `1.2.9`.

## 1.2.6

### Improvements
- **Codex / Claude usage widgets**: Standardized both widgets to refresh every 60 seconds and added manual reload support.
- **App updates**: Changed automatic release checks to run every 4 hours, with immediate checks after wake and session activation.

### Bug Fixes
- **Claude usage access**: Prevented background refreshes from repeatedly prompting for Keychain or sudo-style password access. Only the explicit Allow Access action can show the system prompt.
- **Wake recovery**: Reconnects Codex and Claude usage checks after lid close/open, screen wake, and session reactivation with immediate and delayed refresh attempts.
- **Popup clicks**: Rebuilds popup panels after display and wake changes, fixes multi-screen popup positioning, and restores panel ordering so widget clicks keep working.
- **Time widget visibility**: Keeps the configured time widget in a protected trailing slot so it remains fully visible before the native macOS status area.

## 1.2.5

### Improvements
- **Codex / Claude usage widgets**: Added an in-popup settings view to adjust warning and critical thresholds without editing the TOML file manually. The widgets and popup progress bars now react to your saved thresholds immediately.
- **About menu**: Fixed the main GitHub link so it points to the `barik-enhanced` repository.

### Bug Fixes
- **Status area recovery**: Improved native macOS status area measurement refresh after wake, screen wake, and session reactivation so the bar recovers more reliably from sleep and display changes.

## 1.2.4

### Bug Fixes
- **What's New / Update banner spacing**: Fixed the system banner reserving empty space between the settings gear and the trailing edge when no visible banner was being shown. The banner container now collapses completely unless it has real content.

## 1.2.3

### Bug Fixes
- **AeroSpace Spaces widget**: Fixed the Spaces widget getting stale after long uptimes, wake cycles, day changes, or transient AeroSpace command failures. The widget now re-detects the provider, refreshes on recovery events, and keeps the last good state instead of clearing itself on temporary errors.

### Improvements
- Added a new **Reload** widget to manually reload config and refresh widgets from the menu bar
- Improved AeroSpace command execution with timeout handling and reduced redundant queries
- Restored the app display name/version for the new release

## 1.2.2

### Bug Fixes
- **Background bar trailing gap**: Fixed recurring gap between the background bar's right edge and the system status area. Removed inflated measurement offset and added overlap margin so the background always reaches the system icons cleanly.

## 1.2.1

### Bug Fixes
- **Background bar gap**: Fixed the background bar extending beyond widget area after updates, causing a visible black gap between the last widget and the right edge. Background now respects system status area width on the trailing side.

## 1.2.0

### Bug Fixes
- **Window Level Recovery**: Fixed widgets appearing on top of everything after a system crash or freeze. Panel window levels are now re-applied automatically to self-correct corrupted z-ordering.

### Improvements
- Added wake-from-sleep observer to reset panels after sleep/wake cycles, preventing stale window state

## 1.1.1

### Improvements
- Fix widget spacing on small screens (MacBook) — widgets no longer wrap or overlap
- Fix changelog popup pointing to wrong repository
- Fix "What's new" banner leaving empty gap when dismissed
- Auto-detect native macOS status area width precisely using invisible probe
- Updater now checks for updates from the correct repository

## 1.1.0

### Bug Fixes
- **CPU Monitor**: Fixed CPU usage always showing 0%. The previous implementation used an incorrect `sysctlbyname("vm.loadavg")` call that always failed. Switched to `host_processor_info()` with proper memory management.
- **Memory Safety**: Fixed a use-after-free bug in the CPU monitor that caused memory corruption. A `defer` block was incorrectly freeing memory still needed for delta calculations between update cycles.
- **Widget Overlap**: Fixed Barik widgets overlapping with native macOS status bar items (WiFi, battery, clock, Control Center). Added automatic detection of the system status area width using an invisible `NSStatusItem` probe.

### Improvements
- Right padding now dynamically adjusts to the actual width of native macOS menu bar items
- CPU usage now shows accurate per-core aggregated values with user/system breakdown

## 1.0.0

### Barik Enhanced — Initial Release
- Fork of Barik by mocki-toki, rebranded as Barik Enhanced
- 20+ configurable widgets: CPU/RAM, Network Activity, Battery, Weather, Now Playing, Spaces, Volume, Brightness, and more
- TOML-based configuration with hot-reload
- Multi-monitor support
- Drag-and-drop widget reordering
- Widget configurator UI
- Homebrew installation support

## 0.5.1

> This release was supported by **ALinuxPerson** _(help with the appearance configuration, 1 issue)_, **bake** _(1 issue)_ and **Oery** _(1 issue)_

- Added yabai.path and aerospace.path config properties
- Fixed popup design
- Fixed Apple Music integration in Now Playing widget
- Added experimental appearance configuration:

```toml
### EXPERIMENTAL, WILL BE REPLACED BY STYLE API IN THE FUTURE
[experimental.background] # settings for blurred background
displayed = true          # display blurred background
height = "default"        # available values: default (stretch to full screen), menu-bar (height like system menu bar), <float> (e.g., 40, 33.5)
blur = 3                  # background type: from 1 to 6 for blur intensity, 7 for black color

[experimental.foreground] # settings for menu bar
height = "default"        # available values: default (55.0), menu-bar (height like system menu bar), <float> (e.g., 40, 33.5)
horizontal-padding = 25   # padding on the left and right corners
spacing = 15              # spacing between widgets

[experimental.foreground.widgets-background] # settings for widgets background
displayed = false                            # wrap widgets in their own background
blur = 3                                     # background type: from 1 to 6 for blur intensity
```

## 0.5.0

![Header](https://github.com/user-attachments/assets/182e7930-feb8-4e46-a691-7a54028d21a1)

> This release was supported by **AltaCursor** _([2 cups of coffee](https://ko-fi.com/mocki_toki), 3 issues)_ and **farhanmansurii** _(help with Spotify player)_

**Popup** — a new feature that allows opening an extended and interactive view of a widget (e.g., the battery charge indicator widget) by clicking on it. Currently, popups are available for the following **barik** widgets: Now Playing, Network, Battery, and Time (Calendar).

We want to make **barik** more useful, powerful, and convenient, so feel free to share your ideas in [Issues](https://github.com/mocki-toki/barik/issues/new), and contribute your work through [Pull Requests](https://github.com/mocki-toki/barik/pulls). We’ll definitely review everything!

Other changes:

- Added a new **Now Playing** widget — allowing control of music in desktop applications like Apple Music and Spotify. We welcome your suggestions for supporting other music services: https://github.com/mocki-toki/barik/issues/new
- More customization: Space key and title visibility, as well as a list of applications that will always be displayed by application name.
- Added the ability to switch windows and spaces by mouse click.
- Fixed the `calendar.show-events` config property functionality.
- Fixed screen resolution readjust
- Added auto update functionality, what's new popup

## 0.4.1

> This release was supported by **Oery** _(1 issue)_

- Fixed a display issue with the Notch.

## 0.4.0

> This release was supported by **AltaCursor** _(2 issues)_

- Added support for the `~/.barik-config.toml` configuration file.
- Added AeroSpace support 🎉.
- Fixed 24-hour time format.
- Fixed a desktop icon display issue.

## 0.3.0

- Added a network widget (Wi-Fi/Ethernet status).
- Fixed an incorrect color in the events indicator.
- Prioritized displaying events that are not all-day events.
- Added a maximum length for the focused window title.
- Updated the application icon.
- Added power plug battery status.

## 0.2.0

- Added support for a light theme.
- Added the application icon.

## 0.1.0

- Initial release.
