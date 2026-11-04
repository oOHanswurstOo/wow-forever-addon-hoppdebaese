# Hoppdebäse

Hoppdebäse turns in-game milestones into realistic workout prompts. It supports
level-ups, player deaths, flight path starts, dungeon completions, and every tenth
completed quest, with
Easy, Medium, Hard, and Extreme scaling. Extreme doubles Hard challenge amounts
and daily goals. Each physical exercise has a conservative daily goal; after
filling its progress bar, that exercise rests until the next day.

## Install

1. Extract the `Hoppdebaese` folder into your game's `Interface/AddOns` folder.
2. Ensure the path is `Interface/AddOns/Hoppdebaese/Hoppdebaese.toc`.
3. Restart the game or run `/reload`, then enable **Hoppdebäse** on the
   character-selection AddOns screen.

## Commands

- `/hopp settings` opens difficulty, trigger, and equipment settings.
- `/hopp progress` shows daily goal bars and all-time totals for every challenge.
- `/hopp leaderboard` shows completed challenges and per-workout guild totals.
- `/hopp test` opens and animates a test challenge box.

**Rest & Swap** replaces the current physical exercise and disables it for the
current login session. When all available exercises are complete or resting,
future boxes offer only standing/stretching, hydration, and eye-rest prompts.

Challenges use built-in WoW icons, so no external copyrighted image files are
distributed. Guild-chat announcements can be disabled in settings. All settings,
daily progress, and all-time totals are saved per character.

All-time volume and completion counts remain available for a level-60 overview.
Per-exercise completion counts start with version 0.1.0; older aggregate totals
remain intact, but cannot be converted reliably into historical challenge counts.

Settings and window size/position are saved per WoW installation. Dungeon event
availability varies by client; the addon safely registers the common Classic-derived
and modern completion events that may be exposed by WoW Forever. Guild rankings use
WoW addon messages, so another player appears after both players are online in the
same guild with Hoppdebäse enabled.
