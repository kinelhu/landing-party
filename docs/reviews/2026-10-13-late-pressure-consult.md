# Late pressure and tempers: design consult (Fable), 2026-10-13

Asked during the overnight run after the era bases showed a late player untouched and tempers able to leave a
careful player alone. Summary (the full answer was given in session; this keeps its decisions):

1. **The late base: transit is the target class.** Three causes: `choose_strip` required known defence 0 though
   `strip_site` already keeps the camp out of turret reach (a bug); intel cannot see a base 300+ tiles out, and
   rails were not sensed; a walled interior scores near zero after one turn-back. Rule: a line cell (pole or rail
   with no player turret within 60 tiles) is a cheap target (force 4, cool 5 minutes, no tried penalty, value x2);
   rails 3, signals 2. Grubstake strips any outpost with a camp site beyond turret reach. A camp left to mine its
   full time claims the patch; a second becomes a Grubstake outpost on the player's ore. A late player should lose,
   per hour, an outpost dark for minutes, a strip camp's ore, and, ignoring two camps, a patch to assault; an alert
   every 20-30 minutes, a trip out every 40-60.
2. **Tempers: Serenity's line moves.** Rejected: "first is always Grubstake" (loses the seeded opening) and "the
   floor provokes" (breaks the temper). Rule: from 30 minutes after landing, a Serenity settlement's perimeter
   grows 30 tiles every 10 minutes, announced every 30 minutes, with a named warning one step before it encloses a
   player structure (10 minutes to pull back); capped at the nearest player structure + 40 and 450 from origin,
   never over another corporation's disc. The floor: after 20 quiet minutes the next step comes at once.
   Encroachment provokes as before. Tests: no operation before provocation; perimeter notices and a named warning;
   provocation by encroachment within 90 minutes of landing; a counter-run where the player pulls back sees none.
