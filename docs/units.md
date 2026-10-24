# Unit roster

Written by `scripts/roster.py` from the game's prototypes (`scripts/check.sh` dumps them) and `shared.lua`:
do not edit by hand. Damage is one shot's, before research and plates (a corporation's research raises its
category's damage; a plated unit carries extra resistance). Grubstake's copies (`lp-grubstake-*`) share these
stats in its colours. Hits air: whether its weapon can touch a flier (`landing-party/air.lua`); one that cannot
turns from a flier to a ground target it can hurt (`landing-party/scripts/aim.lua`).

## aegis

Line: a rail cannon on an armoured hull, one heavy slug; against the player's battle tanks.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1100 | 5.4 tiles/s | 38 lp-rail | 16 | 1/s | physical -5 30%, explosion -5 40%, laser -5, electric -5, lp-bite 60% | no | 95 parts |

Fielded by: Kessler-Hayashi, research: line branch, era 2, after warden, 2000 fund.

## battle-tank

the player's siege weapon.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 900 | 5.4 tiles/s | 50 explosion; 120 explosion over 1.5 tiles to buildings | 18 | 0.67/s | physical -3 20%, fire 60%, explosion -5 30%, laser -5, electric -5, lp-bite 60% | no | 6 bandwidth |

Fielded by: the player (a barracks).

## breacher

the player's: demolition charges, for walls (and only a scratch to units).

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 120 | 7.2 tiles/s | 15 explosion over 2.5 tiles; 85 explosion over 2.5 tiles to buildings | 12 | 0.33/s | physical -2 10% | no | 1 bandwidth |

Fielded by: the player (a barracks).

## bred-behemoth-biter



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3000 | 18.0 tiles/s | 90 lp-bite | 1.5 | 1.2/s | physical -12 10%, explosion -12 10% | yes | - |

Fielded by: -.

## bred-big-biter



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 375 | 13.8 tiles/s | 30 lp-bite | 1.5 | 1.7/s | physical -8 10%, explosion 10% | yes | - |

Fielded by: -.

## bred-cinder



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 375 | 13.8 tiles/s | 30 lp-bite | 1.5 | 1.7/s | physical -8 10%, explosion 10% | yes | - |

Fielded by: -.

## bred-medium-biter



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 75 | 14.4 tiles/s | 15 lp-bite | 1 | 1.7/s | physical -4 10%, explosion 10% | yes | - |

Fielded by: -.

## bred-medium-spitter



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | 9.9 tiles/s | - | 14 | 0.6/s | explosion 10% | yes | - |

Fielded by: -.

## bred-small-biter



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 15 | 12.0 tiles/s | 7 lp-bite | 0.5 | 1.7/s | - | yes | - |

Fielded by: -.

## bred-spore



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | 9.9 tiles/s | - | 20 | 0.6/s | explosion 10% | yes | - |

Fielded by: -.

## buggy

Grubstake's raider and escort: fast, a machine gun.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 220 | 12.0 tiles/s | 5 physical | 13 | 6/s | physical -2 15% | yes | 15 parts |

Fielded by: Grubstake (from landing).

## dozer

Wheels: a ram that pushes a wall open for the shotguns.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1800 | 4.2 tiles/s | 60 physical | 2 | 1/s | physical -5 40%, fire 50%, explosion -5 20%, laser -5, electric -5, lp-bite 60% | no | 100 parts |

Fielded by: Grubstake, research: wheels branch, era 3, after slug, 2500 fund.

## flak-buggy

Wheels: scrap flak bursting among fliers, a weak splash on the ground.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 220 | 12.0 tiles/s | 22 explosion over 2 tiles; 3 explosion over 1.5 tiles | 22 | 2/s | physical -2 15% | yes | 20 parts |

Fielded by: Grubstake, research: wheels branch, era 1, 900 fund.

## flame-trooper

the player's: a flamethrower against swarms of bugs and bunched infantry; outranged, and weak on armour.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 120 | 7.2 tiles/s | - | 13 | 15/s | physical -2 10% | yes | 2 bandwidth |

Fielded by: the player (a barracks).

## harrier

air (the scrap drone): weak and cheap, many; flies over walls, cliffs and water.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 80 | 15.0 tiles/s | 6 physical | 12 | 3/s | fire 100% | yes | 15 parts |

Fielded by: Grubstake (from landing).

## hauler

convoys and Grubstake's building trucks; lightly armed.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1500 | 3.9 tiles/s | 4 physical | 10 | 2/s | physical -4 30%, fire 50%, explosion 20% | yes | 30 parts |

Fielded by: both (convoys; Grubstake's builders).

## howitzer-truck



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1200 | 3.9 tiles/s | 4 physical | 10 | 2/s | physical -4 30%, fire 50%, explosion 20% | yes | - |

Fielded by: -.

## infantry

Kessler-Hayashi's Line trooper: a laser beam; the bulk of its raids.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 120 | 7.2 tiles/s | 7 laser | 15 | 2.4/s | physical -2 10%, laser 20% | yes | 10 parts |

Fielded by: Grubstake (from landing); Kessler-Hayashi (from landing).

## lance

Optics: a heavier beam that outranges the player's troopers.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 110 | 7.2 tiles/s | 24 laser | 17 | 1/s | physical -2 10%, laser 20% | yes | 16 parts |

Fielded by: Kessler-Hayashi, research: optics branch, era 1, 900 fund.

## laser-drone

air: Kessler-Hayashi's, armoured, a laser beam; few and dear.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 400 | 12.0 tiles/s | 12 laser | 16 | 3/s | fire 100%, physical -3 40%, laser 20% | yes | 70 parts |

Fielded by: Kessler-Hayashi (from landing).

## prism

Optics: a laser that splits on what it hits to the targets round it; against massed troopers.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 700 | 5.4 tiles/s | (arcs to the next targets); 10 laser; 14 laser | 16 | 1.2/s | physical -3 20%, laser -5, electric -5, explosion 10%, lp-bite 60% | no | 100 parts |

Fielded by: Kessler-Hayashi, research: optics branch, era 2, after lance, 1800 fund.

## railgunner

Kessler-Hayashi's nest clearer: a slug through a 30-tile line, deadly to biters, a scratch to walls.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 140 | 6.0 tiles/s | 250 physical to biters, nests and worms; 10 physical to anything else | 30 | 0.67/s | physical -2 10%, laser 20% | no | 22 parts |

Fielded by: Kessler-Hayashi (from landing).

## rocket-trooper

the player's: rockets against armour, and fliers; slow against a crowd.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 120 | 7.2 tiles/s | 110 explosion | 18 | 0.4/s | physical -2 10% | yes | 2 bandwidth |

Fielded by: the player (a barracks).

## runt



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 15 | 12.0 tiles/s | 7 lp-bite | 0.5 | 1.7/s | - | yes | - |

Fielded by: -.

## sapper

Scrap arms: dynamite over 3 tiles, enemies only; against blobs, and the wall in the way.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 120 | 7.8 tiles/s | 80 explosion over 3 tiles | 11 | 0.33/s | physical -2 10% | no | 30 parts |

Fielded by: Grubstake, research: scrap-arms branch, era 2, 1500 fund.

## scavenger

Wheels (the bomb drone): flies at the player's artillery, mortars and radars and bursts on them.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 60 | 18.0 tiles/s | 150 explosion; 150 explosion over 2.5 tiles | 1.5 | 2/s | fire 100% | yes | 35 parts |

Fielded by: Grubstake, research: wheels branch, era 2, 1800 fund.

## scorcher

Scrap arms: a machine gun, and three bursts of flame for walls, turrets and packs, refilled slowly.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1100 | 5.4 tiles/s | 6 physical | 13 | 6/s | physical -3 25%, fire 100%, explosion -5 30%, laser -5, electric -5, lp-bite 60% | no | 70 parts |

Fielded by: Grubstake, research: scrap-arms branch, era 2, 2000 fund.

## shock

Optics: an arcing electric beam that jumps target to target, a brief stun; against massed troopers.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 160 | 7.2 tiles/s | (arcs to the next targets); 10 electric | 14 | 1.3/s | physical -2 10%, laser 20%, electric 50% | no | 30 parts |

Fielded by: Kessler-Hayashi, research: optics branch, era 3, after lance, 2500 fund.

## shotgun-hand

Grubstake's infantry: three heavy pellets, deadly at the fence, useless against a turret line.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 120 | 10.2 tiles/s | 9 physical (x3) | 9 | 0.94/s | physical -2 10% | yes | - |

Fielded by: Grubstake (from landing, as its infantry).

## skyguard

Line: a long laser that tracks fliers; a weak shot at the ground.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 110 | 7.2 tiles/s | 30 laser over 1 tiles; 8 laser over 0.5 tiles | 22 | 2/s | physical -2 10%, laser 20% | yes | 18 parts |

Fielded by: Kessler-Hayashi, research: line branch, era 1, 900 fund.

## slug

Scrap arms: slugs; against the player's vehicles.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 240 | 12.0 tiles/s | 55 physical | 15 | 1.2/s | physical -2 15%, explosion 40% | yes | 30 parts |

Fielded by: Grubstake, research: scrap-arms branch, era 1, 900 fund.

## tank

armour; cannon rounds that hit buildings three times as hard as units.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 900 | 5.4 tiles/s | 40 explosion; 80 explosion over 1.5 tiles to buildings | 15 | 0.67/s | physical -3 20%, fire 60%, explosion -5 30%, laser -5, electric -5, lp-bite 60% | no | 60 parts |

Fielded by: Kessler-Hayashi (from landing).

## technician



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 80 | 6.0 tiles/s | 1 physical | 1 | 1/s | physical -2 10% | yes | - |

Fielded by: -.

## tesla

Siege: lightning that jumps along a turret line and drains what it strikes of its charge.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 800 | 5.4 tiles/s | (arcs to the next targets); 10 electric; 20 electric | 14 | 0.8/s | physical -3 20%, electric -5 80%, explosion 10%, laser -5, lp-bite 60% | no | 100 parts |

Fielded by: Kessler-Hayashi, research: siege branch, era 3, 2500 fund.

## trooper

the player's: a rifle.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 120 | 7.2 tiles/s | 8 physical | 15 | 3/s | physical -2 10% | yes | 1 bandwidth |

Fielded by: the player (a barracks).

## bred-stomper



| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2000 | walks | - | 5.8500000000000005 | 1/s | physical 50%, laser 40%, impact 80% | yes | - |

Fielded by: -.

## walker

a spider: steps over walls, rockets.

| Health | Speed | A shot | Range | Rate | Resists | Hits air | Cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1600 | walks | 18 physical | 15 | 2.4/s | physical -3 20%, fire 60%, explosion -10 30%, acid 50%, laser -5, electric -5, lp-bite 40% | yes | 100 parts |

Fielded by: Kessler-Hayashi (from landing).
