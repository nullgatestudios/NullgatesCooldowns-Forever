"""Builds Data/Cooldowns.lua from the Forever client's tables on wago.tools.

The group cooldowns worth watching: for each, the class, every trainer rank's spell ID (any rank's
cast counts), the level it's first learned, its cooldown (SpellCooldowns), whether it's a talent
(so it's only shown once a player is seen to have it) and whether the game's built-in Cooldown
Manager lists it (CooldownSet + CooldownSetSpell). Soulstones are tracked by the buff spells the
Soulstone items cast, with the items' 30-minute cooldown.

Usage:
  python tools/generate_cooldown_data.py [--build 1.60.1.70532] [--data DIR]
"""
import argparse
import csv
import io
import json
import os
import sys
import urllib.request
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "NullgatesCooldowns-Forever", "Data", "Cooldowns.lua")
TABLES = ("SpellName", "SpellLevels", "SpellCooldowns", "SkillLineAbility", "CooldownSet", "CooldownSetSpell",
          "ChrSpecialization", "ItemEffect", "ItemXItemEffect", "ItemSparse")
CLASS_LINES = {
    "DRUID": {"574", "134", "573"}, "PALADIN": {"594", "267", "184"}, "WARRIOR": {"26", "256", "257"},
    "SHAMAN": {"375", "373", "374"}, "PRIEST": {"56", "613", "78"}, "HUNTER": {"50", "163", "51"},
    "MAGE": {"237", "8", "6"}, "ROGUE": {"253", "38", "39"}, "WARLOCK": {"355", "354", "593"},
}
CLASS_IDS = {"1": "WARRIOR", "2": "PALADIN", "3": "HUNTER", "4": "ROGUE", "5": "PRIEST", "7": "SHAMAN",
             "8": "MAGE", "9": "WARLOCK", "11": "DRUID"}
# key, class, spell name, type, talent
TRACKED = [
    ("rebirth", "DRUID", "Rebirth", "resurrection", False),
    ("soulstone", "WARLOCK", None, "resurrection", False),
    ("reincarnation", "SHAMAN", "Reincarnation", "resurrection", False),
    ("divineintervention", "PALADIN", "Divine Intervention", "resurrection", False),
    ("innervate", "DRUID", "Innervate", "mana", False),
    ("manatide", "SHAMAN", "Mana Tide Totem", "mana", True),
    ("layonhands", "PALADIN", "Lay on Hands", "defensive", False),
    ("blessingofprotection", "PALADIN", "Blessing of Protection", "defensive", False),
    ("shieldwall", "WARRIOR", "Shield Wall", "defensive", False),
    ("laststand", "WARRIOR", "Last Stand", "defensive", True),
    ("fearward", "PRIEST", "Fear Ward", "defensive", False),
    ("powerinfusion", "PRIEST", "Power Infusion", "utility", True),
    ("challengingshout", "WARRIOR", "Challenging Shout", "utility", False),
    ("challengingroar", "DRUID", "Challenging Roar", "utility", False),
    ("tranquilizingshot", "HUNTER", "Tranquilizing Shot", "utility", False),
]
SOULSTONE_ITEMS = ("Minor Soulstone", "Lesser Soulstone", "Soulstone", "Greater Soulstone", "Major Soulstone")


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "NullgatesCooldowns-generator"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read().decode("utf-8")


def latest_build():
    return json.loads(fetch("https://wago.tools/api/builds/latest"))["wow_classic_beta"]["version"]


def load(name, build, data_dir):
    if data_dir:
        with open(os.path.join(data_dir, name + ".csv"), encoding="utf-8") as f:
            text = f.read()
    else:
        text = fetch("https://wago.tools/db2/%s/csv?build=%s" % (name, build))
    return list(csv.DictReader(io.StringIO(text)))


def to_int(value):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return 0


def build(t):
    names = {r["ID"]: r["Name_lang"] for r in t["SpellName"]}
    levels = {r["SpellID"]: to_int(r.get("SpellLevel")) or to_int(r.get("BaseLevel")) for r in t["SpellLevels"]}
    cooldowns = {}
    for r in t["SpellCooldowns"]:
        cooldowns[r["SpellID"]] = max(cooldowns.get(r["SpellID"], 0), to_int(r["CategoryRecoveryTime"]), to_int(r["RecoveryTime"]))
    spec_class = {r["ID"]: CLASS_IDS.get(r["ClassID"]) for r in t["ChrSpecialization"]}
    set_class = {r["ID"]: spec_class.get(r["ChrSpecialization"]) for r in t["CooldownSet"]}
    in_cdm = defaultdict(set)
    for r in t["CooldownSetSpell"]:
        cls = set_class.get(r["CooldownSetID"])
        if cls:
            in_cdm[cls].add(r["SpellID"])

    by_class_name = defaultdict(set)
    for r in t["SkillLineAbility"]:
        for cls, lines in CLASS_LINES.items():
            if r["SkillLine"] in lines:
                by_class_name[(cls, names.get(r["Spell"], ""))].add(r["Spell"])

    # Soulstone buffs: the use spells of the Soulstone items, with the items' cooldown.
    sparse = {r["ID"]: r for r in t["ItemSparse"]}
    effects = {r["ID"]: r for r in t["ItemEffect"]}
    soul_spells, soul_items, soul_cd = set(), set(), 0
    for r in t["ItemXItemEffect"]:
        s, e = sparse.get(r["ItemID"]), effects.get(r["ItemEffectID"])
        if s and e and s.get("Display_lang") in SOULSTONE_ITEMS and names.get(e["SpellID"]) == "Soulstone Resurrection":
            soul_spells.add(e["SpellID"])
            soul_items.add(to_int(r["ItemID"]))
            soul_cd = max(soul_cd, to_int(e["CategoryCoolDownMSec"]), to_int(e["CoolDownMSec"]))

    out = []
    for key, cls, name, kind, talent in TRACKED:
        if key == "soulstone":
            spells, cd, level, cdm = sorted(soul_spells, key=int), soul_cd, 18, False
        else:
            spells = sorted(by_class_name.get((cls, name), set()), key=lambda s: (levels.get(s, 0), int(s)))
            if not spells:
                sys.exit("no spell found for " + name)
            cd = max(cooldowns.get(s, 0) for s in spells)
            level = min((levels.get(s) for s in spells if levels.get(s)), default=0)
            cdm = any(s in in_cdm[cls] for s in spells)
        if not spells or cd <= 0:
            sys.exit("no cooldown for " + key)
        out.append({"key": key, "class": cls, "name": name or "Soulstone", "type": kind, "talent": talent,
                    "spells": [to_int(s) for s in spells], "cooldown": cd // 1000, "level": level, "cdm": cdm,
                    "items": sorted(soul_items) if key == "soulstone" else []})
    return out


def write(build_id, rows):
    lines = [
        "-- Generated by tools/generate_cooldown_data.py from the Forever client data. Do not edit by hand.",
        "local _, ns = ...",
        "",
        'ns.COOLDOWN_DATA_BUILD = "%s"' % build_id,
        "",
        "-- Group cooldowns: class, type, cooldown in seconds, level first learned, whether it's a talent,",
        "-- whether the game's Cooldown Manager lists it, every spell ID that counts as a use and, for",
        "-- Soulstones, the items (the cooldown is on the item).",
        "ns.COOLDOWNS = {",
    ]
    for r in rows:
        lines.append('    { key = "%s", class = "%s", type = "%s", cooldown = %d, level = %d, talent = %s, cdm = %s, spells = { %s } }, -- %s' % (
            r["key"], r["class"], r["type"], r["cooldown"], r["level"], "true" if r["talent"] else "false",
            "true" if r["cdm"] else "false", ", ".join(str(s) for s in r["spells"]) + (" }, items = { " + ", ".join(str(i) for i in r["items"]) if r["items"] else ""), r["name"]))
    lines.append("}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build")
    parser.add_argument("--data")
    args = parser.parse_args()
    build_id = args.build or latest_build()
    rows = build({name: load(name, build_id, args.data) for name in TABLES})
    write(build_id, rows)
    for r in rows:
        print("%-22s %-8s %5ds level %2d%s%s" % (r["key"], r["class"], r["cooldown"], r["level"], " talent" if r["talent"] else "",
              " (Cooldown Manager)" if r["cdm"] else ""))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
