# Amethyst

`~/.amethyst.yml` links to `amethyst.yml`. YAML values override GUI preferences
on launch; restart **Amethyst**, not Chrome, after editing. Keyboard shortcuts
remain in the GUI/plist because YAML modifier definitions can reset shortcuts.

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
On macOS they also check Amethyst's Foundation/ICU regex engine via Swift.

Source references:
- [Chrome browser accessibility titles](https://github.com/chromium/chromium/blob/main/chrome/browser/ui/views/frame/browser_view.cc) — `GetAccessibleWindowTitleForChannelAndProfile`
- [Native video PiP window](https://github.com/chromium/chromium/blob/main/chrome/browser/ui/views/overlay/video_overlay_window_views.cc) — `OverlayWindowWidgetDelegate`
- [Amethyst 0.24.3 title classification](https://github.com/ianyh/Amethyst/blob/v0.24.3/Amethyst/Preferences/UserConfiguration.swift) — `runningApplication(_:byDefaultFloatsForTitle:)`
