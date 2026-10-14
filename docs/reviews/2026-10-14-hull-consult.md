# Hull, camp strikes and the grudge: design consult (Fable), 2026-10-14

After the 6-hour campaign runs (12345: no artillery lander kill, batteries all lost; 777: one battery stood all game,
the hull never went down, every new settlement fell to a camp strike within 4 minutes) and the grudge as first built.

1. **The hull.** The share isn't the problem; the geometry is. The campaign's battery sits ~200 tiles from the lander
   with 224 reach, so it can only touch generators within ~24 tiles past the lander, and later hubs are founded "near
   the outpost furthest from every hub" (90–160 tiles out, with their own compound generators). No radius ≥ 60 fixes
   that from one side. Rules:
   - Count only generators within 80 tiles of the lander (the first hub and its pad band; later hubs fall outside by
     the founding rule). Share stays half. Floor: fewer than 2 counted generators means the hull is down (a camp
     lander is bare anyway).
   - Site the battery on the hub's side: place only where ≥ 60% of counted generators are in reach, else try the next
     clear site, else accept a site 30 (not 50) tiles from corp turrets. That is the commitment: the position is
     chosen to be lost.
   - Era 4: artillery-shell-range-1 (×1.3 = 291 tiles).
   Measure: hull_down ≥ 1 per battery placed on 777; 1–2 kills; shells per kill ≤ 60; every kill preceded by
   generator kills.

2. **Camp strikes.** A 3-minute camp has no depot (army.cap = depots × …, so garrison 0) and no walls (fortify needs
   parts > 80 and a fabricator); 40 units at era 3 (30 troopers, 8 breachers, 2 battle tanks) cannot lose. The
   earlier targets "a camp falls to a squad" and "a landing survives 2 h" can't both hold unless the camp has
   something. One rule, legible in-game: the drop escort. A landing arrives with its pad walled and 4 corner turrets
   (the layout already describes the pad as walled; build it on arrival, not at fortify) plus an escort of
   6 + 4·level units that counts as garrison until the first depot opens. Measure (777, 6 h): camp strikes win ≤ 1
   of 3; at least one landing reaches mature; a corporation consolidates by hour 6; 12345 unchanged (Serenity's camp
   still holds, batteries still lost).

3. **The grudge.** Three changes:
   - The doubled cap is dead on arrival: cap = #depots × (10 + 5·level), a camp has 0 depots for its first ~20+
     minutes, and the 30-minute window expires around when the depot opens. Apply the doubling to the drop escort
     instead, and start the 30-minute cap clock at the first depot.
   - "Every corporation provoked for good" breaks Serenity's provoked-only contract: a player fighting the thief gets
     the wall-builder as a permanent enemy. Provoke the killed corporation for good; the others take a threat zone
     and a resistance bump, no provocation.
   - Name the grudge when it lands: lp.grudge at the kill is fine; add a line when the angry landing arrives so the
     player links cause and answer.
   Keep: siege whatever its level; only the next landing carries it.
