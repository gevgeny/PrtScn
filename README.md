<p align="center">
  <img src="docs/icon.png" width="160" height="160" alt="PrtScn icon">
</p>

<h1 align="center">PrtScn</h1>

<p align="center">
  <strong>One key, one screenshot.</strong><br>
  A tiny macOS menu bar app that takes a screenshot when you tap a single key.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-27%2B-blue?logo=apple&logoColor=white" alt="macOS 27+">
  <img src="https://img.shields.io/badge/version-0.1.0-teal" alt="Version 0.1.0">
  <img src="https://img.shields.io/badge/Swift-AppKit%20%2B%20SwiftUI-orange?logo=swift&logoColor=white" alt="Swift">
</p>

<p align="center">
  <a href="./builds/PrtScn.0.1.0.zip"><strong>Download v0.1.0</strong></a> ·
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#building-from-source">Build</a>
</p>

---

## How it works

Tap <kbd>🌐 fn</kbd>, or the left or right <kbd>⌃</kbd>, <kbd>⌥</kbd>, <kbd>⌘</kbd> or <kbd>⇧</kbd> on its own, and PrtScn runs the screenshot action you assigned to that key. It uses the built-in macOS `screencapture` tool, so files land where <kbd>⇧</kbd><kbd>⌘</kbd><kbd>3</kbd> puts them.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/menu-dark.png">
    <img src="docs/menu-light.png" width="370" alt="PrtScn menu">
  </picture>
</p>

Only a clean single press counts. Holding the key with anything else (another key, a modifier, a click, a scroll), or longer than a second, does nothing, so shortcuts like <kbd>⌥</kbd><kbd>⌘</kbd><kbd>X</kbd>, <kbd>fn</kbd><kbd>F1</kbd> or <kbd>⌃</kbd>-click keep working.

## Features

- **Eight actions**: capture screen or area to file or clipboard, **Capture area & edit** (opens the Markup editor), **Copy text from area** (on-device OCR), **Pick color** (copies `#RRGGBB`), or **Record** (opens the macOS Screenshot toolbar)
- **Nine keys**: Fn / Globe, and left and right Control, Option, Command and Shift, each with its own action
- **Pause** without quitting
- **Launch at login**

## Installation

1. Download [**PrtScn v0.1.0**](./builds/PrtScn.0.1.0.zip) and unzip it. The app is signed with a Developer ID and notarized by Apple. Older builds are in [`builds`](./builds).
2. Move **PrtScn.app** to `/Applications` and launch it. The icon appears in the menu bar.
3. Allow PrtScn in **Privacy & Security → Accessibility** and **Input Monitoring**, then restart it.
4. Allow **Screen Recording** when macOS asks on the first screenshot.
5. Click the icon and pick an action for each key you want to use.
6. If you use Fn, set **System Settings → Keyboard → Press 🌐 key to** to **Do Nothing**.

## Building from source

Requires Xcode 27 (the app icon is an Icon Composer `.icon` file). No dependencies.

```sh
git clone https://github.com/gevgeny/PrtScn.git
cd PrtScn
open PrtScn.xcodeproj   # build & run the "PrtScn" scheme
```
