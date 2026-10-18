# Action ideas

Candidate actions for single-press keys, highest priority first. Priority = usefulness × how annoying the
built-in shortcut is ÷ build effort.

| # | Action | Today on macOS | How | Effort |
|---|---|---|---|---|
| ✅ | **Copy text from area (OCR)** | No shortcut | Done: `screencapture -i` to a temp file → Vision `RecognizeTextRequest` → pasteboard | Medium |
| 2 | **Start screen recording** (area / full screen) | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>5</kbd> + click | `screencapture -v` / `-V` (needs a stop gesture, e.g. tap again) | Medium |
| 3 | **Capture window** | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>4</kbd> + <kbd>Space</kbd> + click | `screencapture -iW` | Low |
| 4 | **Lock screen** | <kbd>⌃</kbd><kbd>⌘</kbd><kbd>Q</kbd> | Post the system lock shortcut, or `pmset displaysleepnow` with password-on-wake | Low |
| 5 | **Mute / unmute microphone** | No shortcut | CoreAudio input device mute, show state in menu bar | Medium |
| 6 | **Emoji picker** | <kbd>fn</kbd><kbd>E</kbd> / <kbd>⌃</kbd><kbd>⌘</kbd><kbd>Space</kbd> | `NSApp.orderFrontCharacterPalette(nil)` | Low |
| 7 | **Mission Control** | <kbd>⌃</kbd><kbd>↑</kbd> / F3 | `open -a "Mission Control"` | Low |
| 8 | **Show desktop** | <kbd>fn</kbd><kbd>F11</kbd> / <kbd>⌘</kbd><kbd>F3</kbd> | Post the system shortcut; fragile | Medium |
| 9 | **Toggle dark mode** | No shortcut | AppleScript `System Events` → `appearance preferences` (Automation permission) | Low |
| 10 | **Toggle Do Not Disturb / Focus** | No default shortcut | Run a user Shortcut (`shortcuts run`); no public API | Medium |

## Screen capture ideas (fit the PrtScn name)

| # | Action | Why | How | Effort |
|---|---|---|---|---|
| ✅ | **Pick color** | Designers and developers need it all the time, and macOS has no global shortcut | Done: `NSColorSampler` loupe, result to the clipboard as `#RRGGBB` (sRGB) | Low |
| 1 | **Scan QR / barcode from area** | QR codes on screen (Wi-Fi, 2FA, links) with no phone needed | Same flow as OCR: `screencapture -i`, then a Vision barcode request, then the clipboard or open the URL | Low |
| 2 | **Capture window** | The most common screenshot; takes 3 steps today | `screencapture -iW`, plus `-o` for no shadow | Low |
| ✅ | **Capture & edit** | Annotate straight away | Done: saves like ⇧⌘4, opens the system Markup extension (`com.apple.MarkupUI.Markup`), Preview as fallback | Low |
| 4 | **Timed capture (5 s)** | Catch hover states, open menus and tooltips | `screencapture -T 5` | Low |
| 5 | **Start / stop recording** | Tap once to start, tap again to stop | `screencapture -v`, stopped by ending the process on the next tap; pulse the icon while recording | Medium |
| 6 | **Translate text from area** | Read a foreign-language UI or image | OCR plus Apple's Translation framework, shown in a small popover | Medium |
| 7 | **Pin area on screen** | Keep a reference image floating above other windows | `screencapture -ic`, then a borderless always-on-top window | Medium |
| 8 | **Repeat last area** | Capture the same region again, for before/after comparisons | Needs our own selection UI to remember the rectangle | High |

## Not planned

- **Double-tap a key** for a second action per key: doubles the slots, but single taps must wait ~250 ms
  to rule out a second tap. Revisit if keys run out.
- **Caps Lock** as a trigger: needs a system-wide `hidutil` remap to stop it toggling caps.
- **Key overloading** (tap = action, hold = modifier): we only listen, we never change what a key does.

## Rename

If the app pivots from "one key, one screenshot" to "one key, one action", rename it to **Tap Once**
(tagline: *Tap once. Done.*). Literal, says what you do. Check App Store, GitHub and domain availability first.
