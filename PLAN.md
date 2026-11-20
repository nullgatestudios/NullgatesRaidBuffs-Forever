# Nullgate's Raid Buffs - Forever: Plan

Status: planning, with no code written yet. Planned on 2026-11-20.

- **Folder:** `NullgatesRaidBuffs-Forever`
- **Saved variables:** `NullgatesRaidBuffsDB` (per character)
- **Commands:** `/nbuffs` and `/raidbuffs`

## Decisions made

- Works for every class, in party and raid.
- Buff data (every rank, single and group versions, durations, levels, which class casts each) is generated from Forever client data (wago.tools), never typed by hand.
- The running-low warning scales with each buff's duration.
- Consumable checks are off by default.
- Ships as 1.0.0-beta.1 for testers.

## Forever buffs (client build 1.60.1.70532)

| Class | Buff | Forever | Classic |
| :--- | :--- | :--- | :--- |
| Priest | Power Word: Fortitude (6 ranks) / Prayer of Fortitude (2) | 60 min / 60 min | 30 / 60 |
| Priest | Divine Spirit (4) / Prayer of Spirit (1) | 60 min / 60 min | 30 / 60 |
| Priest | Shadow Protection (3) / Prayer of Shadow Protection (1) | 10 min / 20 min | same |
| Priest | Fear Ward | 3 min | same |
| Mage | Arcane Intellect (5) / Arcane Brilliance (1) | 60 min / 60 min | 30 / 60 |
| Mage | Amplify Magic (4), Dampen Magic (5) | 10 min | same |
| Druid | Mark of the Wild (7) / Gift of the Wild (2) | 60 min / 60 min | 30 / 60 |
| Druid | Thorns (6) | 10 min | same |
| Paladin | Might, Wisdom, Kings, Light, Salvation and Greater versions | 60 min | 5 / 15 |
| Warlock | Unending Breath, Detect Invisibility | 10 min | same |
| Shaman | Water Walking, Water Breathing | 10 min | same |
| Warrior | Battle Shout (7) | 3 min | 2 min |
| Hunter | Trueshot Aura (5) | 30 min | same |

Self buffs for reminders: Inner Fire 10 min; Frost, Ice and Mage Armor 30 min; Demon Skin and Demon Armor 30 min; Righteous Fury 30 min; Lightning Shield and Water Shield 10 min.

Spells at level 0 in the client data (Earth Shield, Commanding Shout, Fel Armor, Spirit of the Alpha) are left out until a tester confirms they exist in game.

## The constraint that shapes the design

The buff button is a **secure button** whose spell and target are set in advance and only change **out of combat**. Mid-fight it keeps its last target.

---

## Phase 0: Repo and checks

- Repo, README, plan, license, logo, CurseForge workflow, `/zips` packaging, tests.
- `/nbuffs check` in-game self test. Confirm in the Forever client:
  - Auras on raid members return spell IDs and expiration times.
  - Range checks on group members.
  - Which level 0 spells exist.

## Phase 1: Buff data

- Generator script reading SkillLineAbility, SpellMisc, SpellDuration and SpellLevels.
- Buff families: each single buff linked to its group version and rank levels.
- Unit tests.

## Phase 2: The grid

- Players by group against buffs; green, yellow, red, greyed when out of range.
- Throttled refresh so a 40-player raid doesn't lag.

## Phase 3: Your buff button

- Next missing player, group version when several in one group need it, highest rank they can receive.

## Phase 4: Ready check, report, consumables, settings, languages, beta

- Ready check view, rate-limited report, consumable check, self-buff reminders.
- Settings window and Nullgate's Addon Config page; the 10 client languages.
- DESCRIPTION.md, CHANGELOG.md, 1.0.0-beta.1.
