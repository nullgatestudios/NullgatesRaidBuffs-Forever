# Nullgate's Raid Buffs - Forever

> **Status: beta** (1.0.0-beta.1). Looking for testers of every class. See [CHANGELOG.md](CHANGELOG.md).

**Nullgate's Raid Buffs** shows who in your party or raid is missing which buff in **World of Warcraft: Forever**, and gives you one button that casts your own class's buff on the next player who needs it.

Every duration comes from the Forever client: Fortitude, Arcane Intellect, Mark of the Wild and Divine Spirit last an hour there.

---

## How It Works

1. **Open the buff grid**, or let it appear on a ready check. Players are rows, buffs are columns.
2. **Each cell is green, yellow or red**: up, running low, or missing. Players out of range show greyed out instead of missing.
3. **Click your buff button**: it casts your class's buff on the next player missing it, or the group version when several in one group need it.

Buttons can't change their target in combat, so mid-fight the button keeps its last target until combat ends.

---

## Features

- **Buff grid** for Fortitude, Mark of the Wild, Arcane Intellect, Divine Spirit, Shadow Protection, blessings and Thorns. Buffs nobody in the group can cast are hidden.
- **Your buff button** with single and group versions, at the highest rank each player can receive.
- **Running-low warnings** scaled to each buff: 5 minutes for one-hour buffs, 1 minute for ten-minute buffs.
- **Ready check view** that shows only what's missing.
- **Report button** that posts missing buffs to group chat, rate-limited.
- **Consumable check** for flasks and Well Fed, off by default.
- **Self-buff reminders** for Inner Fire, the mage and warlock armors, and Lightning and Water Shield.
- **Settings** in its own window or inside Nullgate's Addon Config.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nbuffs` or `/raidbuffs` | Show or hide the buff grid. |
| `/nbuffs report` | Post missing buffs to group chat. |
| `/nbuffs config` | Open the settings. |
| `/nbuffs check` | Test what the addon needs in your game client and save the results. |

---

## Installation

Not released yet. Once it is:

1. Download the latest release from CurseForge or the GitHub releases page.
2. Extract the `NullgatesRaidBuffs-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in and type `/nbuffs`.

---

## Part of the Nullgate Addon Suite

- **Nullgate's Addon Config**: one settings hub and profile manager for the whole suite.
- **Nullgate's Blessings**, **Totems**, **Cooldowns**, **Restock** and more.

---

## Development

| Task | Command |
| :--- | :--- |
| Refresh the buff data after a client patch | `python tools/generate_buff_data.py` (reads the latest Forever build from wago.tools) |
| Run the tests | `lua tests/run.lua`, `lua tests/smoke.lua` and `lua tests/locales.lua` |
| Build `zips/NullgatesRaidBuffs-Forever-<version>.zip` | `.\package.ps1` (or `.\package.ps1 -Version 1.0.0` to set the version first) |

Publishing a GitHub release uploads that version to CurseForge (`.github/workflows/curseforge.yml`); pushes only run the tests.

---

## License

Source-available, all rights reserved. See [LICENSE.md](LICENSE.md).
