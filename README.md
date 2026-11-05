# Hoppdebäse

Hoppdebäse turns in-game milestones into realistic workout prompts. It supports
level-ups, player deaths, flight path starts, dungeon completions, and every tenth
completed quest or profession skill point milestone, with
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
- `/hopp todo` opens saved challenges waiting to be completed.
- `/hopp rested` shows exercises excluded for the current login session.
- `/hopp help` opens details for controls, settings, and every exercise.
- `/hopp progress` shows daily goal bars and all-time totals for every challenge.
- `/hopp leaderboard` shows completed challenges and per-workout guild totals.
- `/hopp test` opens and animates a test challenge box.

The responsive challenge box rolls quickly at first, slows substantially near
the end of its four-second animation,
and colors low amounts green through high amounts red. Every settled challenge
is added to the persistent Todo window, which opens automatically after the roll.
The translucent Todo panel can be resized and left open; its geometry is saved.
Complete challenges there to credit
daily and all-time progress. **Replace Exercise (Session)** replaces the latest
Todo entry and excludes that physical exercise until relogging. Open **Rested**
to view excluded exercises and restore any of them immediately. **Minimize**
hides the roll window while leaving its Todo entry available. The **?** button
opens the complete in-addon reference.

When all available exercises are complete or resting, future boxes offer only
standing/stretching, hydration, and eye-rest prompts.

Profession skill milestones at 10, 20, 30, and so on use only wellness breaks
for primary professions, Cooking, Fishing, and First Aid. These include
**Stoßlüften**: open the window and walk around for 30 to 120 seconds.

Pull-ups use dedicated ranges: Easy is always 1; Medium scales from 1-2 to 2-4;
Hard scales from 2-3 to 4-5; Extreme is exactly double the corresponding Hard
range. Event multipliers do not increase pull-up amounts.

Challenges use built-in WoW icons, so no external copyrighted image files are
distributed. Guild-chat announcements can be disabled in settings. Settings,
Todo entries, daily progress, all-time totals, and window geometry are saved per
character in `HoppdebaeseDB`.

Addon version updates do not clear this data: WoW keeps SavedVariables separately
from addon files, and new defaults only fill missing fields. Keep the
`Hoppdebaese` folder name and `HoppdebaeseDB` SavedVariables key unchanged. This
release also reads the older account-wide `GuildFitWheelDB` and migrates it when
the current character has no existing progress.

All-time volume and completion counts remain available for a level-60 overview.
Per-exercise completion counts start with version 0.1.0; older aggregate totals
remain intact, but cannot be converted reliably into historical challenge counts.

Dungeon event availability varies by client; the addon safely registers the common Classic-derived
and modern completion events that may be exposed by WoW Forever. Guild rankings use
WoW addon messages, so another player appears after both players are online in the
same guild with Hoppdebäse enabled.
