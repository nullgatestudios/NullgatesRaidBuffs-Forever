**Nullgate's Raid Buffs** shows who in your party or raid is missing which buff in **World of Warcraft: Forever**, and gives you one button that casts your own class's buff on the next player who needs it.

No more scanning forty buff bars before the pull, or asking "who still needs Fort?" in raid chat.

> **Beta:** this is an early test version and we're looking for players of every class to try it. If something doesn't work, run `/nbuffs check`, then send us the results with a short description.

---

## Features

- **Buff grid**: players by group against Fortitude, Mark of the Wild, Arcane Intellect, Divine Spirit, Shadow Protection, blessings and Thorns. Green is up, yellow is running low, red is missing. Buffs nobody in your group can cast are hidden.
- **Out of range is not missing**: players too far away to check show greyed out.
- **Your buff button**: casts your class's buff on the next player missing it, at the highest rank they can receive, or the group version when several players in one group need it.
- **Accurate durations**: every buff time is read from the Forever client. Fortitude, Arcane Intellect, Mark of the Wild and Divine Spirit last an hour there.
- **Running-low warnings** scaled to each buff: 5 minutes before an hour-long buff ends, 1 minute before a ten-minute buff ends.
- **Ready check view** that pops up with only what's missing.
- **Report button** that posts missing buffs to group chat, limited so it can't spam.
- **Consumable check** for flasks and Well Fed, off unless you turn it on.
- **Self-buff reminders** for Inner Fire, Mage, Ice and Frost Armor, Demon Skin and Demon Armor, and Lightning and Water Shield.
- **Key binding** for your buff button, under Key Bindings > AddOns.

---

## How It Works

1. **Open the grid** with `/nbuffs`, or start a ready check.
2. **See what's missing** at a glance.
3. **Click your buff button** until your column is green.

The game doesn't allow buttons to change their target during combat. Mid-fight, the button keeps its last target and updates as soon as combat ends.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nbuffs` or `/raidbuffs` | Show or hide the buff grid. |
| `/nbuffs report` | Post missing buffs to group chat. |
| `/nbuffs config` | Open the settings. |
| `/nbuffs check` | Test what the addon needs in your game client and save the results (for bug reports). |

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

The addon uses your game's language automatically. You can switch at any time in the settings; it applies after a `/reload`. The translations were made with machine assistance, so some wording may not be quite right. Corrections are welcome: send a message here on CurseForge or [report on our website](https://nullgatestudios.com/report?addon=raid-buffs).

## Installation

1. Download the latest file.
2. Extract the `NullgatesRaidBuffs-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in, join a group and type `/nbuffs`.

---

## Good to Know

- Works for every class, in parties and raids.
- Buff durations and ranks are read from the Forever client data, not copied from original Classic.
