# Nullgate's Cooldowns - Forever: Plan

Status: phases 0 to 4 built as 1.0.0-beta.1 on 2026-11-20; the in-game checks wait for testers (`/ncd check`). Planned on 2026-11-20.

Built notes: 15 group cooldowns, cooldown times from the Forever client (Lay on Hands 20 min, Shield Wall 15 min, Fear Ward 3 min); Divine Shield isn't tracked (it only helps the paladin); the Rebirth/Soulstone notice is a chat line for you, not a group announcement; the list filters by type only.

- **Folder:** `NullgatesCooldowns-Forever`
- **Saved variables:** `NullgatesCooldownsDB` (per character)
- **Commands:** `/ncd` and `/cooldowns`

## Decisions made

- **Builds on the game's built-in Cooldown Manager.** Your own cooldowns are shown by the Cooldown Manager; this addon does not draw a second display for them. The addon covers what the Cooldown Manager can't: other players' cooldowns.
- **The tracked spell list comes from the Cooldown Manager's own data** (the CooldownSet and CooldownSetSpell tables, one set per class in Forever), filtered to group-relevant cooldowns, plus the few it doesn't include.
- Works for every class, in party and raid.
- Ships as 1.0.0-beta.1 for testers. It needs group testing.

## What the Forever Cooldown Manager already covers (client build 1.60.1.70532)

In the Cooldown Manager's lists: Rebirth, Innervate, Tranquility, Challenging Roar, Lay on Hands, Divine Intervention, Blessing of Protection, Shield Wall, Last Stand, Challenging Shout, Recklessness, Fear Ward, Power Infusion, Mana Tide Totem, Ice Block, Evasion, Vanish.

Not in its lists, added by this addon: Reincarnation, Soulstone, Tranquilizing Shot.

## Where timers come from (best first)

1. **Players running the addon** share their own cooldowns (exact, including talent and gear reductions), read from the same cooldown information the Cooldown Manager uses.
2. **Casts seen on group members** (`UNIT_SPELLCAST_SUCCEEDED` for party and raid units), timed with the base cooldown from client data.
3. **The combat log**, if it's available to addons in Forever, for casts the other two miss.

A player out of range or offline shows as unknown, not as ready.

---

## Phase 0: Repo and checks

- Repo, README, plan, license, logo, CurseForge workflow, `/zips` packaging, tests.
- `/ncd check` in-game self test. Confirm in the Forever client:
  - The Cooldown Manager's addon API (`C_CooldownViewer`) and what it returns for your class.
  - Whether your own cooldown information is readable in combat, or only out of combat.
  - `UNIT_SPELLCAST_SUCCEEDED` for group members, and combat log availability.
  - Addon messages in party and raid.

## Phase 1: Spell data

- Generator script: Cooldown Manager spells per class plus the extras, with base cooldowns and a type (resurrection, mana, defensive, utility).
- Unit tests.

## Phase 2: Tracking

- The three timer sources merged per player and spell, best source wins.

## Phase 3: Display

- Compact group list grouped by type, a filter per type, ready or minutes left.
- Click a ready cooldown to whisper the player.

## Phase 4: Sync polish, announce, settings, languages, beta

- Share on join so late joiners get exact timers; optional announce when Rebirth or Soulstone is used.
- Settings window and Nullgate's Addon Config page; the 10 client languages.
- DESCRIPTION.md, CHANGELOG.md, 1.0.0-beta.1.
