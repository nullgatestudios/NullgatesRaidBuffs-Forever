"""Builds Data/Buffs.lua from the Forever client's tables on wago.tools.

Buff families (one column of the grid each): the class that casts it, the single-target spell and the
group spell, every trainer rank with the level it's learned at and its duration, and the reagent the
group spell uses. Also the self buffs for reminders, the flask buffs (the use spells of every
"Flask of ..." item) and Well Fed, for the optional consumable check.

Usage:
  python tools/generate_buff_data.py [--build 1.60.1.70532] [--data DIR]
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
OUT = os.path.join(ROOT, "NullgatesRaidBuffs-Forever", "Data", "Buffs.lua")
TABLES = ("SpellName", "SpellLevels", "SpellMisc", "SpellDuration", "SpellReagents", "SkillLineAbility",
          "ItemSparse", "ItemEffect", "ItemXItemEffect")
CLASS_LINES = {
    "PRIEST": {"56", "613", "78"}, "MAGE": {"237", "8", "6"}, "DRUID": {"574", "134", "573"},
    "PALADIN": {"594", "267", "184"}, "WARLOCK": {"355", "354", "593"}, "SHAMAN": {"375", "373", "374"},
    "WARRIOR": {"26", "256", "257"}, "HUNTER": {"50", "163", "51"},
}
# key, class, single spell, group spell (or None)
FAMILIES = [
    ("fortitude", "PRIEST", "Power Word: Fortitude", "Prayer of Fortitude"),
    ("intellect", "MAGE", "Arcane Intellect", "Arcane Brilliance"),
    ("wild", "DRUID", "Mark of the Wild", "Gift of the Wild"),
    ("spirit", "PRIEST", "Divine Spirit", "Prayer of Spirit"),
    ("shadow", "PRIEST", "Shadow Protection", "Prayer of Shadow Protection"),
    ("thorns", "DRUID", "Thorns", None),
]
# Paladin blessings: shown as one read-only column (any blessing counts).
BLESSINGS = ["Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Light", "Salvation",
             "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings",
             "Greater Blessing of Light", "Mass Salvation"]
# Self buffs: any one of each group counts.
SELF = [
    ("MAGE", ["Frost Armor", "Ice Armor", "Mage Armor"]),
    ("WARLOCK", ["Demon Skin", "Demon Armor"]),
    ("PRIEST", ["Inner Fire"]),
    ("SHAMAN", ["Lightning Shield", "Water Shield"]),
]
WELL_FED = "Well Fed"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "NullgatesRaidBuffs-generator"})
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
    misc = {r["SpellID"]: r for r in t["SpellMisc"]}
    durations = {r["ID"]: to_int(r["Duration"]) for r in t["SpellDuration"]}
    reagents = {r["SpellID"]: to_int(r.get("Reagent_0")) for r in t["SpellReagents"]}
    by_class_name = defaultdict(list)
    for r in t["SkillLineAbility"]:
        for cls, lines in CLASS_LINES.items():
            if r["SkillLine"] in lines and levels.get(r["Spell"]):
                by_class_name[(cls, names.get(r["Spell"], ""))].append(r["Spell"])

    def ranks(cls, name):
        out = []
        for spell in sorted(set(by_class_name.get((cls, name), [])), key=lambda s: levels[s]):
            m = misc.get(spell)
            out.append({"spell": to_int(spell), "level": levels[spell],
                        "duration": durations.get(m["DurationIndex"], 0) // 1000 if m else 0})
        return out

    families = []
    for key, cls, single, group in FAMILIES:
        s = ranks(cls, single)
        if not s:
            sys.exit("no ranks for " + single)
        g = ranks(cls, group) if group else []
        reagent = reagents.get(str(g[0]["spell"]), 0) if g else 0
        families.append({"key": key, "class": cls, "single": single, "group": group, "singleRanks": s,
                         "groupRanks": g, "reagent": reagent})

    ids_by_name = defaultdict(list)
    for spell, name in names.items():
        ids_by_name[name].append(to_int(spell))
    blessing_ids = [min(ids_by_name[n]) for n in BLESSINGS if ids_by_name.get(n)]
    self_buffs = []
    for cls, group in SELF:
        ids = [to_int(ranks(cls, n)[0]["spell"]) for n in group if ranks(cls, n)]
        if ids:
            self_buffs.append((cls, ids))

    sparse = {r["ID"]: r for r in t["ItemSparse"]}
    effects = {r["ID"]: r for r in t["ItemEffect"]}
    flasks = set()
    for r in t["ItemXItemEffect"]:
        s = sparse.get(r["ItemID"])
        e = effects.get(r["ItemEffectID"])
        if s and e and s.get("Display_lang", "").startswith("Flask of ") and to_int(e["SpellID"]):
            flasks.add(to_int(e["SpellID"]))
    well_fed = min(ids_by_name[WELL_FED]) if ids_by_name.get(WELL_FED) else 0
    return families, blessing_ids, self_buffs, sorted(flasks), well_fed


def write(build_id, families, blessings, self_buffs, flasks, well_fed):
    lines = [
        "-- Generated by tools/generate_buff_data.py from the Forever client data. Do not edit by hand.",
        "local _, ns = ...",
        "",
        'ns.BUFF_DATA_BUILD = "%s"' % build_id,
        "",
        "-- Buff families, one grid column each: casting class, single and group spells with their ranks",
        "-- ({ spell ID, level learned, duration in seconds }) and the group spell's reagent.",
        "ns.BUFF_FAMILIES = {",
    ]
    for f in families:
        def r(lst):
            return ", ".join("{ %d, %d, %d }" % (x["spell"], x["level"], x["duration"]) for x in lst)
        lines.append('    { key = "%s", class = "%s", single = { %s }, group = { %s }, reagent = %d }, -- %s%s' % (
            f["key"], f["class"], r(f["singleRanks"]), r(f["groupRanks"]), f["reagent"], f["single"],
            (" / " + f["group"]) if f["group"] else ""))
    lines += ["}", "",
              "-- Paladin blessings (one read-only column): a spell ID for each blessing's name.",
              "ns.BLESSING_SPELLS = { %s }" % ", ".join(str(i) for i in blessings), "",
              "-- Self buffs to remind about: any one of each class's list counts (a spell ID per buff name).",
              "ns.SELF_BUFFS = {"]
    for cls, ids in self_buffs:
        lines.append("    %s = { %s }," % (cls, ", ".join(str(i) for i in ids)))
    lines += ["}", "",
              "-- Consumables: the buffs every \"Flask of ...\" item gives, and Well Fed.",
              "ns.FLASK_SPELLS = { %s }" % ", ".join(str(i) for i in flasks),
              "ns.WELL_FED_SPELL = %d" % well_fed]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build")
    parser.add_argument("--data")
    args = parser.parse_args()
    build_id = args.build or latest_build()
    families, blessings, self_buffs, flasks, well_fed = build({name: load(name, build_id, args.data) for name in TABLES})
    write(build_id, families, blessings, self_buffs, flasks, well_fed)
    for f in families:
        print("%-10s %d single ranks (%ds), %d group ranks, reagent %d" % (f["key"], len(f["singleRanks"]),
              f["singleRanks"][-1]["duration"], len(f["groupRanks"]), f["reagent"]))
    print("blessings %d, self buffs %d classes, flasks %d, well fed %d" % (len(blessings), len(self_buffs), len(flasks), well_fed))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
