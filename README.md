<p align="center">
  <img src="docs/icon.png" width="160" height="160" alt="PrtScn icon">
</p>

<h1 align="center">PrtScn</h1>

<p align="center">
  <strong>One key, one screenshot.</strong><br>
  A tiny macOS menu bar app that takes a screenshot when you tap a single key.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%2B-blue?logo=apple&logoColor=white" alt="macOS 26+">
  <img src="https://img.shields.io/badge/version-0.1.6-teal" alt="Version 0.1.6">
  <img src="https://img.shields.io/badge/Swift-AppKit%20%2B%20SwiftUI-orange?logo=swift&logoColor=white" alt="Swift">
  <a href="https://buymeacoffee.com/eugene.g"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black" alt="Buy me a coffee"></a>
</p>

<p align="center">
  <a href="./builds/PrtScn.0.1.6.zip"><strong>Download v0.1.6</strong></a> ·
  <a href="#features">Features</a> ·
  <a href="#permissions">Permissions</a>
</p>

---

## How it works

Tap <kbd>🌐 fn</kbd> or another modifier key on its own, or press one of the MacBook top-row keys, and PrtScn runs the action you assigned to it. It uses the standard macOS screenshot tools you're already used to.

Beyond screenshots, a key can also do a few handy screen tricks: pick the color of any pixel, copy the text from any area of the screen straight to the clipboard, or capture an area and jump right into Markup to annotate it.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/menu-dark.png">
    <img src="docs/menu-light.png" width="600" alt="PrtScn menu">
  </picture>
</p>

For modifier keys, only a clean single tap counts. Holding the key with anything else (another key, a modifier, a click, a scroll), or for longer than a quick tap, does nothing, so shortcuts like <kbd>⌥</kbd><kbd>⌘</kbd><kbd>X</kbd>, <kbd>fn</kbd><kbd>F1</kbd> or <kbd>⌃</kbd>-click keep working. A tap right after typing is ignored too, so brushing a modifier mid-sentence doesn't take a screenshot.

Top-row keys (<kbd>F1</kbd>–<kbd>F12</kbd> as pressed without fn: brightness, Mission Control, Spotlight, media, volume) fire on press and replace their usual action. Keys you leave on **Default** keep working as before, and so does any top-row key pressed with <kbd>⌘</kbd>, <kbd>⌥</kbd>, <kbd>⌃</kbd> or <kbd>⇧</kbd>. Assigning <kbd>F8</kbd> also stops it from launching Music.

## Features

- **Eight actions**: capture screen or area to file or clipboard, **Capture area & edit** (opens the Markup editor), **Copy text from area** (on-device OCR), **Pick color to clipboard** (as `#RRGGBB`), or **Record screen…** (opens the macOS screenshot toolbar in recording mode)
- **21 keys**, each with its own action:
  - **Modifiers**: Fn / Globe, left and right Control, Option, Command and Shift. Right Control shows as N/A unless a keyboard that has one is connected
  - **Top row**: F1–F12, shown with their MacBook keycap symbols
- **Pause** without quitting
- **Launch at login**

## Permissions

| Permission | Why |
|---|---|
| **Input Monitoring** | Notice single key presses, including 🌐 fn. Asked when you assign your first key; listen-only, modifier keys are never blocked or changed |
| **Accessibility** | Block the usual action of an assigned top-row key (brightness, volume…) so only yours runs. Asked when you assign your first F-key; not needed otherwise |
| **Screen Recording** | Take screenshots; macOS asks on the first capture |

Grant them in **System Settings → Privacy & Security**; no restart needed. If you use fn, also set **System Settings → Keyboard → Press 🌐 key to** to **Do Nothing**.

## Support

PrtScn is free. If it saves you a few keystrokes, you can [buy me a coffee](https://buymeacoffee.com/eugene.g) ☕. Bugs and ideas: [open an issue](https://github.com/gevgeny/PrtScn/issues).
