# SuitBreak

A local multiplayer card game built with **Godot 4.7**. Empty your hand before everyone else — the last player still holding cards loses.

Full rules live in [`docs/game_rules.md`](docs/game_rules.md).

---

## What it is

SuitBreak uses one standard 52-card deck. Players take turns following the current suit or breaking it with another suit. Rounds end in one of two ways:

- **Suit break** — the highest card on the table is collected; the breaker leads next.
- **No break** — everyone followed suit; table cards go to the discard pile; highest card leads next.

The game opens with **A♠**: whoever is dealt it must play it as the first card of the match.

---

## Features

| Mode | Description |
| --- | --- |
| **Host Room** | One phone runs the authoritative game over local Wi‑Fi / hotspot. |
| **Join Room** | Other phones connect to the host and play the same match. |
| **Play vs Bots** | Single-device practice against simple bots (2–4 players). |

LAN discovery auto-fills the host IP when possible. Enter your name before hosting or joining.

---

## Requirements

- [Godot 4.7](https://godotengine.org/) (project uses Forward+)
- For **Android**: Android SDK, JDK 17, Godot Android export templates
- For **LAN play**: both devices on the same Wi‑Fi or phone hotspot; `INTERNET` permission enabled in export (already set in `export_presets.cfg`)

---

## Run locally

1. Open the project folder in Godot.
2. Open `main.tscn` in the **2D** tab.
3. Press **F5** (Play Project).

---

## Play on two phones

1. **Host phone** — turn on hotspot or share Wi‑Fi, open SuitBreak, enter your name, tap **Host Room**, wait in the lobby.
2. **Join phone** — connect to the same network, enter your name, tap **Join Room** (IP should auto-fill).
3. **Host** — tap **Start Game** once at least two players are in the lobby.

The host runs the rules engine; joining phones send card plays and display synced game state.

---

## Export to Android

1. **Project → Export… → Android**
2. Set SDK / JDK paths under **Editor → Editor Settings → Export → Android** if needed.
3. Export APK and install on both devices.

Reinstall after icon or permission changes.

---

## Project layout

```text
suit-break/
├── core/           # Rules engine (no UI, no networking)
│   ├── game_engine.gd
│   ├── game_state.gd
│   ├── deck.gd
│   └── ...
├── net/
│   └── network.gd  # ENet host/join + UDP LAN discovery (autoload: Network)
├── ui/             # Screen scripts
├── scenes/         # Godot scenes (menu, lobby, table, cards)
├── docs/
│   └── game_rules.md
├── main.tscn       # Entry scene
└── project.godot
```

### Architecture

- **`core/`** — Pure game logic: deal, legal plays, suit breaks, round resolution, win/lose. Testable without nodes or network.
- **`net/network.gd`** — LAN lobby: host/join, player names, start match. Autoloaded as `Network`; scripts use `SuitBreakNetwork.I`.
- **`ui/` + `scenes/`** — Menus, lobby, table UI, card views. Table RPCs sync state from host to clients.

Extra seats in a 3– or 4-player lobby are filled by bots on the host.

---

## Key scripts

| File | Role |
| --- | --- |
| `core/game_engine.gd` | Authoritative rules; deal, turns, round end, snapshots |
| `net/network.gd` | Host/join, lobby roster, match start |
| `ui/main_menu.gd` | Host Room / Join Room / vs Bots |
| `ui/lobby.gd` | Wait for players; host starts the match |
| `ui/table.gd` | Table UI; host runs engine, clients sync via RPC |

---

## Status

- Core rules implemented (including opening **A♠**)
- LAN multiplayer with lobby (host + join)
- Android export preset configured
- Bot fill for empty seats in larger lobbies

See [`docs/game_rules.md`](docs/game_rules.md) for invariants, edge cases, and future ideas.
