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
  <img src="https://img.shields.io/badge/version-0.1.3-teal" alt="Version 0.1.3">
  <img src="https://img.shields.io/badge/Swift-AppKit%20%2B%20SwiftUI-orange?logo=swift&logoColor=white" alt="Swift">
  <a href="https://buymeacoffee.com/eugene.g"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black" alt="Buy me a coffee"></a>
</p>

<p align="center">
  <a href="./builds/PrtScn.0.1.3.zip"><strong>Download v0.1.3</strong></a> ·
  <a href="#features">Features</a> ·
  <a href="#permissions">Permissions</a>
</p>

---

## How it works

Tap <kbd>🌐 fn</kbd> or another modifier key on its own, and PrtScn runs the action you assigned to it. It uses the standard macOS screenshot tools you're already used to.

Beyond screenshots, a key can also do a few handy screen tricks: pick the color of any pixel, copy the text from any area of the screen straight to the clipboard, or capture an area and jump right into Markup to annotate it.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/menu-dark.png">
    <img src="docs/menu-light.png" width="370" alt="PrtScn menu">
  </picture>
</p>

Only a clean single press counts. Holding the key with anything else (another key, a modifier, a click, a scroll), or for longer than a quick tap, does nothing, so shortcuts like <kbd>⌥</kbd><kbd>⌘</kbd><kbd>X</kbd>, <kbd>fn</kbd><kbd>F1</kbd> or <kbd>⌃</kbd>-click keep working.

## Features

- **Eight actions**: capture screen or area to file or clipboard, **Capture area & edit** (opens the Markup editor), **Copy text from area** (on-device OCR), **Pick color to clipboard** (as `#RRGGBB`), or **Record screen…** (opens the macOS screenshot toolbar in recording mode)
- **Eight keys**: Fn / Globe, Control, and left and right Option, Command and Shift, each with its own action
- **Pause** without quitting
- **Launch at login**

## Permissions

| Permission | Why |
|---|---|
| **Input Monitoring** | Notice single key presses, including 🌐 fn. Asked when you assign your first key; listen-only, keys are never blocked or changed |
| **Screen Recording** | Take screenshots; macOS asks on the first capture |

Grant them in **System Settings → Privacy & Security**; no restart needed. If you use fn, also set **System Settings → Keyboard → Press 🌐 key to** to **Do Nothing**.

## Support

PrtScn is free. If it saves you a few keystrokes, you can [buy me a coffee](https://buymeacoffee.com/eugene.g) ☕. Bugs and ideas: [open an issue](https://github.com/gevgeny/PrtScn/issues).
