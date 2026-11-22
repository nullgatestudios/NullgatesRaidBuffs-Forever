# Changelog

All notable changes to Nullgate's Raid Buffs - Forever.

## [1.0.0-beta.3] - 2026-11-21

### Fixed

- No more "Auras cannot be accessed when secret" error. While the game hides a player's buffs from addons, usually in combat, the addon keeps using what it last saw on them, with the timers counting down.

## [1.0.0-beta.2] - 2026-11-21

### Fixed

- No more error when the game hides a group member's range from addons. That player is treated as in range.
- Buffs the game hides from addons, usually in combat, are skipped instead of causing an error.
- `/nrb check` shows "secret" for a hidden range instead of failing.

## [1.0.0-beta.1] - 2026-11-20

First test version, looking for players of every class to try it.

### New

- **Buff grid**: everyone in your party or raid against Fortitude, Arcane Intellect, Mark of the Wild, Divine Spirit, Shadow Protection, Thorns and blessings. Green is up, yellow is running low, red is missing, grey is out of range. Only buffs someone in the group can cast are shown.
- **Accurate durations** read from the Forever client data (Fortitude, Arcane Intellect, Mark of the Wild and Divine Spirit last an hour). "Running low" scales with each buff: 5 minutes for hour-long buffs, a minute for ten-minute buffs.
- **Your buff button**: casts your class's buff on the next player who needs it, at the highest rank they can receive, or the group version when three or more in one group need it and you carry the reagent. Right-click to choose which of your buffs it casts.
- **Ready check view**: the grid pops up showing only what's missing.
- **Report**: posts missing buffs to group chat, at most once every 30 seconds.
- **Consumable check** (off by default): flask and Well Fed columns.
- **Self-buff reminder**: a chat line when your own Inner Fire, armor or shield is missing.
- **Key binding** for the buff button under Key Bindings > AddOns.
- **Settings** in its own window or inside Nullgate's Addon Config.
- **`/nbuffs check`**: reports what the addon reads from your client for bug reports.
- Available in English, Deutsch, Español, Français, Italiano, Português (Brasil), Русский, 한국어, 简体中文 and 繁體中文.

### Good to know

- The buff button can't change its target during combat. Mid-fight it keeps its last target and updates as soon as combat ends.
