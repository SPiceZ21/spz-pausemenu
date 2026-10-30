# spz-pausemenu

> Replaces the GTA pause menu.

![version](https://img.shields.io/badge/version-1.2.1-ff6200) ![SPiceZ-Core](https://img.shields.io/badge/SPiceZ--Core-beta-18181b)

## Overview

`Esc` opens a SPiceZ pause menu: map, teleport to hub, leave the current queue / race / minigame, settings and quick tiles for the main screens.

## Features

- Map and settings shortcuts
- Leave race / queue / minigame
- Quick tiles for spawner, leaderboard, crew, appearance

## Requirements

| Resource | Type |
|---|---|
| `ox_lib` | third-party |
| `spz-core` | SPiceZ module |

## Installation

Included in the [txAdmin recipe](https://github.com/SPiceZ21/spz-txrecipe). Manual install:

1. Download `spz-pausemenu` from GitHub (latest release, or the repository) into your `resources` folder.
2. Add to `server.cfg`, after its requirements:

```cfg
ensure spz-pausemenu
```

## Configuration

- `config.lua`

See the file for every option.

## Exports

| Export | Side |
|---|---|
| `Close` | client |
| `IsOpen` | client |
| `Open` | client |

```lua
exports["spz-pausemenu"]:Close(...)
```

---

Part of **SPiceZ-Core** — [documentation](https://github.com/SPiceZ21/Docs) · [all modules](https://github.com/SPiceZ21/Docs/blob/main/modules/README.md)
