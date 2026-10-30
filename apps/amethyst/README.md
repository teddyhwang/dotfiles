# Amethyst

## Provisioning and preference recovery

Package setup calls the standalone helper, which also works before Amethyst's
first launch:

```sh
sh scripts/amethyst.sh
```

It creates the needed directories and links `~/.amethyst.yml` to `amethyst.yml`
and the custom layout to `uniform-columns.js` in Amethyst's Application Support
Layouts directory. Existing conflicting files use the shared confirmation/backup
flow; agreeing to replace them preserves originals in dotfiles backups.

For a fresh HOME with no preference file or defaults domain, the helper imports
`com.amethyst.Amethyst.plist` as the saved settings/shortcut profile using macOS
`defaults import`. Snapshot `EncodedWindowManager`, `NS*` window state and `SU*`
updater metadata are excluded. YAML/layout files and this saved plist are the
repository sources; this does not capture your latest runtime customizations.

Existing preferences, **including stock defaults**, are preserved on normal
runs. To deliberately reset settings and shortcuts to the saved profile, quit
Amethyst first, then run from the repository:

```sh
sh scripts/amethyst.sh --restore-preferences
```

This exports current preferences into a unique, private directory under
`~/.local/state/dotfiles/backups/amethyst.XXXXXX/` before resetting. Because
`defaults import` merges rather than replaces keys, an existing domain is deleted
only after backup and profile preparation succeed; deletion failure refuses the
import. Fresh imports do not delete an absent domain. If reset import fails, the
helper attempts to restore the exported backup (clearing any partially imported
domain first), reports whether rollback succeeded, and returns failure either
way. The backup is always retained. If rollback fails, keep Amethyst closed and
recover from the printed backup path before launching it. Existing
monitor/window state, updater metadata and unrelated keys are retained. The
entire `KeyboardShortcuts_*` namespace is replaced, so stock-only shortcuts not
in the saved profile remain unbound. Saved migration markers and legacy command
entries are retained to prevent recreation of default bindings.

No preferences are imported while Amethyst is running. The helper never launches,
quits or restarts it. **Launch Amethyst manually afterward**, and grant/regrant
Accessibility permission in System Settings if requested.

YAML values override GUI preferences on launch; restart **Amethyst**, not Chrome,
after editing. Keyboard shortcuts remain in the GUI/plist because YAML modifier
definitions can reset shortcuts.

Provisioning regression tests (native commands and Homebrew are mocked):

```sh
node --test tests/amethyst-setup.test.mjs
```

## Chrome: tile browser windows, float PiP

The floating list is a **tiling allowlist** (`floating-is-blacklist: false`).
Chrome windows tile only when their accessibility title has Chrome's browser
signature, such as `Page title - Google Chrome - Profile` or
`Page title - Google Chrome (Incognito)`.

Chrome adds its browser branding to normal browser and ordinary popup windows,
but not native video Picture-in-Picture or Document Picture-in-Picture windows.
The Google PiP extension uses the native `video.requestPictureInPicture()` API.
This avoids maintaining exceptions for websites, video titles, languages of
video titles, or overlay sizes. A regular browser tab displaying Meet or a
PiP tutorial still tiles; the separate PiP overlay does not.

Empty titles intentionally do not match. Amethyst treats an unmatched empty
title as provisional and retries while the window is being created. The old
`.*` allowlist matched empty titles immediately, before a PiP title could load.
The existing small-window preference remains enabled, but is not the PiP fix:
it only applies when **both** dimensions are below 500 pixels.

### Limits

- Amethyst exposes bundle ID/title rules, not browser window types or video
  detection. The branding rule is a heuristic based on Chrome's accessibility
  implementation, not a universal OS-level overlay detector.
- Extensions that create an **ordinary Chrome popup** rather than native or
  Document PiP still tile. Use native PiP for those, or manually toggle floating.
- A title deliberately containing the full browser signature can also match.
  Changes to Chrome's accessibility title format may require updating the rule.
- Rules apply when Amethyst tracks a window, not continuously on every title
  change. Restart Amethyst to reclassify already tracked windows.

### Verification

```sh
node --test tests/amethyst-window-rules.test.mjs
```

Tests parse the actual YAML, cover browser/profile/Incognito/Guest titles,
video and Document PiP titles, empty startup titles, and the popup limitation.
On macOS they also check Amethyst's Foundation/ICU regex engine via
JavaScript for Automation.

Source references:
- [Chrome browser accessibility titles](https://github.com/chromium/chromium/blob/main/chrome/browser/ui/views/frame/browser_view.cc) — `GetAccessibleWindowTitleForChannelAndProfile`
- [Native video PiP window](https://github.com/chromium/chromium/blob/main/chrome/browser/ui/views/overlay/video_overlay_window_views.cc) — `OverlayWindowWidgetDelegate`
- [Amethyst 0.24.3 title classification](https://github.com/ianyh/Amethyst/blob/v0.24.3/Amethyst/Preferences/UserConfiguration.swift) — `runningApplication(_:byDefaultFloatsForTitle:)`

## Rex: tile session windows, float Settings

Rex hides the Settings window's title bar, but its accessibility title is
`Settings - <Section>` (for example `Settings - Server`). Session windows are
`<terminal title> - <dir> - <session>`. The rule tiles every title except
`Settings` alone or followed by exactly one ` - <Section>` segment, so a
terminal titled `Settings` inside a session still tiles. Empty startup titles
float so Amethyst retries classification. The same test file covers these
cases.
