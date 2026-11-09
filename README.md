# Hoppdebäse

Hoppdebäse turns in-game milestones into realistic workout prompts. It supports
level-ups, player deaths, flight path starts, dungeon completions, and every tenth
completed quest or profession skill point milestone, with
Easy, Medium, Hard, and Extreme scaling. Extreme doubles Hard challenge amounts
and daily goals. Each physical exercise has a conservative daily goal; after
filling its progress bar, that exercise rests until the next day.

## Install

1. Extract the lowercase `hoppdebaese` folder into your game's `Interface/AddOns` folder.
2. Ensure the exact path is `Interface/AddOns/hoppdebaese/Hoppdebaese.toc`. On case-sensitive systems, `Hoppdebaese` will not work.
3. Restart the game or run `/reload`, then enable **Hoppdebäse** on the
   character-selection AddOns screen.

## Commands

- `/hopp settings` opens difficulty, trigger, and equipment settings.
- `/hopp todo` opens saved challenges waiting to be completed.
- `/hopp rested` shows exercises excluded for the current login session.
- `/hopp help` opens details for controls, settings, and every exercise.
- `/hopp progress` shows daily goal bars and all-time totals for every challenge.
- `/hopp leaderboard` shows completed challenges and per-workout guild totals.
- `/hopp top3` shows the top three guild contributors and total for each exercise.
- `/hopp test` opens and animates a test challenge box.

The responsive challenge box rolls quickly at first, slows substantially near
the end of its four-second animation,
and colors low amounts green through high amounts red. Every settled challenge
is added to the persistent Todo window, which opens automatically after the roll.
The compact Todo panel contains only each icon, challenge, and completion action.
It can be resized down to a small translucent list and left open; its geometry is saved.
Complete challenges there to credit
daily and all-time progress. **Replace Exercise (Session)** replaces the latest
Todo entry and excludes that physical exercise until relogging. Open **Rested**
to view excluded exercises and restore any of them immediately. **Minimize**
hides the roll window while leaving its Todo entry available. The **?** button
opens the complete in-addon reference.

Every addon window has a **Reset Window** button that restores only its original
size and position. It does not reset settings, Todo entries, tokens, daily
progress, all-time totals, or guild data.

Completing a physical exercise rolled within the top 10% of its maximum value
awards one persistent **Fuultier token**. Three tokens can skip one physical exercise from
Todo without crediting its amount or completion. Cat and wellness challenges
never award tokens and never show the token Skip action. Token totals are shown
in both Todo and Settings.

When all available exercises are complete or resting, future boxes offer lighter
wellness prompts plus any enabled cat or significant-other prompts.

Profession skill milestones at 10, 20, 30, and so on mix wellness breaks with
Easy exercises for primary professions, Cooking, Fishing, and First Aid. Breaks include
**Stoßlüften**: open the window and walk around for 30 to 120 seconds.

Settings provide a quest interval from 3 to 15 completed quests (default 10),
separate roll/completion guild announcements, and equipment filters. The
enabled-by-default **Cats** setting adds "play with your cats" and "give each
cat pets" prompts plus litter-box cleanup to every difficulty wheel at a 1.2
selection weight. Cat play
runs from 5 to 20 minutes; shorter rolls are red and longer rolls are green. Guild
messages include the triggering event; completion messages end with a random
Swiss-German/Twitch-chat line. Shower/face-wash prompts have a four-hour cooldown, and a
special Swiss-German challenge has a one-percent roll chance.

The Easy prompt pool includes a posture check. The disabled-by-default
**Significant other** setting adds "Spend quality time with your significant
other" with no assigned duration.

The exercise pool includes both forward and reverse lunges. Calf raises use a
slightly higher amount scale than standard repetition exercises.

The minimap icon opens Todo with left-click, Settings with right-click, and the
guild leaderboard with Shift-left-click. The guild leaderboard links to a second
Top 3 view showing leaders and combined totals for every exercise.

Pull-ups use dedicated ranges: Easy is always 1; Medium scales from 1-2 to 2-4;
Hard scales from 2-3 to 4-5; Extreme is exactly double the corresponding Hard
range. Event multipliers do not increase pull-up amounts.

Challenges use built-in WoW icons, so no external copyrighted image files are
distributed. Guild-chat announcements can be disabled in settings. Settings,
Todo entries, daily progress, all-time totals, and window geometry are saved per
character in `HoppdebaeseDB`.

Addon version updates do not clear this data: WoW keeps SavedVariables separately
from addon files, and new defaults only fill missing fields. Keep the
lowercase `hoppdebaese` folder name and `HoppdebaeseDB` SavedVariables key unchanged. This
release also reads the older account-wide `GuildFitWheelDB` and migrates it when
the current character has no existing progress.

All-time volume and completion counts remain available for a level-60 overview.
Per-exercise completion counts start with version 0.1.0; older aggregate totals
remain intact, but cannot be converted reliably into historical challenge counts.

Dungeon event availability varies by client; the addon safely registers the common Classic-derived
and modern completion events that may be exposed by WoW Forever. Guild rankings use
WoW addon messages, so another player appears after both players are online in the
same guild with Hoppdebäse enabled.
