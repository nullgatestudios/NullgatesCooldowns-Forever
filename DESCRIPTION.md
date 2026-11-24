**Nullgate's Cooldowns** shows your group's important cooldowns in **World of Warcraft: Forever**: who has Rebirth, Innervate, Soulstone, Lay on Hands or Shield Wall ready, and how long until the rest come back.

It's built to sit alongside the game's own Cooldown Manager. The Cooldown Manager already shows your cooldowns, so this addon focuses on everyone else's, using the same spell lists to decide which cooldowns matter.

> **Beta:** this is an early test version and we're looking for groups to try it. If something doesn't work, run `/ncd check`, then send us the results with a short description.

---

## Features

- **Group cooldown list**: every important cooldown in your party or raid, ready or with minutes left, grouped by type (resurrection, mana, defensive and utility).
- **Uses the game's Cooldown Manager lists**, plus the cooldowns they leave out: Reincarnation, Soulstone and Tranquilizing Shot.
- **Exact timers** from group members who also run the addon, including cooldowns shortened by talents. For everyone else, timers start from the casts the addon sees.
- **Unknown is not ready**: players out of range or offline show as unknown, so you never count on a cooldown that might not be there.
- **Click to request**: click a ready cooldown to whisper that player, for example "Rebirth on Bob, please".
- **Optional chat line for you** when someone uses Rebirth or a Soulstone, saying who it went on.
- **Simple settings**: which types of cooldown to show, whether to list your own, the Rebirth and Soulstone notice and the language.

---

## How It Works

1. **Join a group.** The addon works out which important cooldowns everyone has.
2. **Watch the list.** Ready cooldowns are bright, cooldowns in use count down.
3. **Click one you need.** The player gets a whisper asking for it.

Your own cooldowns stay in the game's Cooldown Manager, and you can choose to also list yourself in the group view.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/ncd` or `/cooldowns` | Show or hide the cooldown list. |
| `/ncd config` | Open the settings. |
| `/ncd lock` / `/ncd unlock` | Lock or unlock the list. |
| `/ncd check` | Test what the addon needs in your game client and save the results (for bug reports). |

---

## Supported Languages

All 10 languages the game client runs in:

- English
- Deutsch (German)
- Español (Spanish)
- Français (French)
- Italiano (Italian)
- Português do Brasil (Brazilian Portuguese)
- Русский (Russian)
- 한국어 (Korean)
- 简体中文 (Simplified Chinese)
- 繁體中文 (Traditional Chinese)

The addon uses your game's language automatically. You can switch at any time in the settings; it applies after a `/reload`. The translations were made with machine assistance, so some wording may not be quite right. Corrections are welcome: send a message here on CurseForge or [report on our website](https://nullgatestudios.com/report?addon=cooldowns).

## Installation

1. Download the latest file.
2. Extract the `NullgatesCooldowns-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in, join a group and type `/ncd`.

---

## Good to Know

- Works for every class, in parties and raids.
- Group members share their cooldowns through hidden addon messages, not chat.
