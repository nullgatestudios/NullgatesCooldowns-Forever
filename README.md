# Nullgate's Cooldowns - Forever

> **Status: beta** (1.0.0-beta.2). Looking for groups to test it. See [CHANGELOG.md](CHANGELOG.md).

**Nullgate's Cooldowns** shows your group's important cooldowns in **World of Warcraft: Forever**: who has Rebirth, Innervate, Soulstone, Lay on Hands or Shield Wall ready, and how long until the rest come back.

Your own cooldowns are already shown by the game's built-in Cooldown Manager, so this addon doesn't duplicate them. It uses the same Cooldown Manager spell lists to decide which cooldowns matter, and adds the ones the game doesn't track, such as Reincarnation, Soulstone and Tranquilizing Shot.

---

## How It Works

1. **The addon learns each player's cooldowns**: from players who also run it (exact timers, including talent-shortened cooldowns), and from what it can see them cast.
2. **A compact list** shows each cooldown as ready or with minutes left, grouped by type: resurrection, mana, defensive, utility.
3. **Click a ready cooldown** to whisper that player, for example *"Rebirth on Bob, please"*.

---

## Features

- **Group cooldown list** for party and raid, with a filter for each type.
- **Built on the game's Cooldown Manager lists**, plus the cooldowns it misses.
- **Exact timers from players running the addon**, best guesses from what's seen for players who don't.
- **Click to request** a cooldown by whisper.
- **Optional chat line for you** when someone uses Rebirth or a Soulstone, saying who it went on.
- **Settings** in its own window or inside Nullgate's Addon Config.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/ncd` or `/cooldowns` | Show or hide the cooldown list. |
| `/ncd config` | Open the settings. |
| `/ncd lock` / `/ncd unlock` | Lock or unlock the list. |
| `/ncd check` | Test what the addon needs in your game client and save the results. |

---

## Installation

Not released yet. Once it is:

1. Download the latest release from CurseForge or the GitHub releases page.
2. Extract the `NullgatesCooldowns-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in and type `/ncd`.

---

## Part of the Nullgate Addon Suite

- **Nullgate's Addon Config**: one settings hub and profile manager for the whole suite.
- **Nullgate's Raid Buffs**, **Blessings**, **Totems**, **Restock** and more.

---

## Development

| Task | Command |
| :--- | :--- |
| Refresh the cooldown data after a client patch | `python tools/generate_cooldown_data.py` (reads the latest Forever build from wago.tools) |
| Run the tests | `lua tests/run.lua`, `lua tests/smoke.lua` and `lua tests/locales.lua` |
| Build `zips/NullgatesCooldowns-Forever-<version>.zip` | `.\package.ps1` (or `.\package.ps1 -Version 1.0.0` to set the version first) |

Publishing a GitHub release uploads that version to CurseForge (`.github/workflows/curseforge.yml`); pushes only run the tests.

---

## License

Source-available, all rights reserved. See [LICENSE.md](LICENSE.md).
