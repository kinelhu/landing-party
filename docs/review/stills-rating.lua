-- The rating gallery (the user, 2026-11-10: "some of those models are rough... send me an artefact so I can rate
-- each"): every modelled building beside its vanilla counterpart, one still a pair, at a zoom that fits both. Generated
-- by tools/rating_film.py from the dump's sizes. scripts/film.sh gallery fresh.zip docs/review/stills-rating.lua
local build, shots = {}, {}
build[#build + 1] = {name = "lp-barracks", force = "player", pos = {-2.2, 0}}
build[#build + 1] = {name = "assembling-machine-2", force = "player", pos = {2.2, 0}}
shots[#shots + 1] = {name = "00-barracks", tick = 240, pos = {-0.0, -0.8}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-muster-point", force = "player", pos = {42.6, 0}}
build[#build + 1] = {name = "steel-chest", force = "player", pos = {45.4, 0}}
shots[#shots + 1] = {name = "01-muster-point", tick = 242, pos = {44.0, -0.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-rally-beacon", force = "player", pos = {86.7, 0}}
build[#build + 1] = {name = "constant-combinator", force = "player", pos = {89.3, 0}}
shots[#shots + 1] = {name = "02-rally-beacon", tick = 244, pos = {88.0, -0.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-threat-scanner", force = "player", pos = {130.7, 0}}
build[#build + 1] = {name = "constant-combinator", force = "player", pos = {133.3, 0}}
shots[#shots + 1] = {name = "03-threat-scanner", tick = 246, pos = {132.0, -0.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-command-relay", force = "player", pos = {173.8, 0}}
build[#build + 1] = {name = "radar", force = "player", pos = {178.2, 0}}
shots[#shots + 1] = {name = "04-command-relay", tick = 248, pos = {176.0, -0.8}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-trade-post", force = "player", pos = {218.7, 0}}
build[#build + 1] = {name = "wooden-chest", force = "player", pos = {221.3, 0}}
shots[#shots + 1] = {name = "05-trade-post", tick = 250, pos = {220.0, -0.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-border-stake", force = "player", pos = {262.9, 0}}
build[#build + 1] = {name = "small-electric-pole", force = "player", pos = {265.3, 0}}
shots[#shots + 1] = {name = "06-border-stake", tick = 252, pos = {264.0, -0.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-claim-marker", force = "player", pos = {-1.1, 44}}
build[#build + 1] = {name = "small-electric-pole", force = "player", pos = {1.4, 44}}
shots[#shots + 1] = {name = "07-claim-marker", tick = 254, pos = {0.0, 43.7}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-pact-breaker", force = "player", pos = {42.6, 44}}
build[#build + 1] = {name = "wooden-chest", force = "player", pos = {45.4, 44}}
shots[#shots + 1] = {name = "08-pact-breaker", tick = 256, pos = {44.0, 43.7}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-player-bait", force = "player", pos = {86.7, 44}}
build[#build + 1] = {name = "wooden-chest", force = "player", pos = {89.3, 44}}
shots[#shots + 1] = {name = "09-player-bait", tick = 258, pos = {88.0, 43.8}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-strip-drill", force = "player", pos = {129.7, 44}}
build[#build + 1] = {name = "electric-mining-drill", force = "player", pos = {134.3, 44}}
shots[#shots + 1] = {name = "10-strip-drill", tick = 260, pos = {132.0, 43.1}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-flak-turret", force = "player", pos = {174.3, 44}}
build[#build + 1] = {name = "laser-turret", force = "player", pos = {177.7, 44}}
shots[#shots + 1] = {name = "11-flak-turret", tick = 262, pos = {176.0, 43.5}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-player-dome", force = "player", pos = {217.3, 44}}
build[#build + 1] = {name = "tesla-turret", force = "player", pos = {222.2, 44}}
shots[#shots + 1] = {name = "12-player-dome", tick = 264, pos = {220.0, 42.8}, zoom = 2.27, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-player-mortar", force = "player", pos = {261.8, 44}}
build[#build + 1] = {name = "artillery-turret", force = "player", pos = {265.8, 44}}
shots[#shots + 1] = {name = "13-player-mortar", tick = 266, pos = {264.0, 43.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-fabricator", force = "lp-serenity", pos = {-2.2, 88}}
build[#build + 1] = {name = "assembling-machine-2", force = "player", pos = {2.2, 88}}
shots[#shots + 1] = {name = "14-kh-fabricator", tick = 268, pos = {-0.0, 87.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-generator", force = "lp-serenity", pos = {42.1, 88}}
build[#build + 1] = {name = "accumulator", force = "player", pos = {45.9, 88}}
shots[#shots + 1] = {name = "15-kh-generator", tick = 270, pos = {44.0, 87.4}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-radar", force = "lp-serenity", pos = {85.8, 88}}
build[#build + 1] = {name = "radar", force = "player", pos = {90.2, 88}}
shots[#shots + 1] = {name = "16-kh-radar", tick = 272, pos = {88.0, 87.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-drill", force = "lp-serenity", pos = {129.7, 88}}
build[#build + 1] = {name = "electric-mining-drill", force = "player", pos = {134.3, 88}}
shots[#shots + 1] = {name = "17-kh-drill", tick = 274, pos = {132.0, 87.1}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-turret", force = "lp-serenity", pos = {174.3, 88}}
build[#build + 1] = {name = "laser-turret", force = "player", pos = {177.7, 88}}
shots[#shots + 1] = {name = "18-kh-laser-turret", tick = 276, pos = {176.0, 87.5}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-gun-turret", force = "lp-serenity", pos = {218.3, 88}}
build[#build + 1] = {name = "gun-turret", force = "player", pos = {221.7, 88}}
shots[#shots + 1] = {name = "19-kh-autocannon", tick = 278, pos = {220.0, 87.5}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-flamer", force = "lp-serenity", pos = {261.8, 88}}
build[#build + 1] = {name = "flamethrower-turret", force = "player", pos = {266.2, 88}}
shots[#shots + 1] = {name = "20-kh-flamer", tick = 280, pos = {264.0, 87.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-pylon", force = "lp-serenity", pos = {-1.6, 132}}
build[#build + 1] = {name = "big-electric-pole", force = "player", pos = {1.1, 132}}
shots[#shots + 1] = {name = "21-kh-pylon", tick = 282, pos = {0.0, 131.5}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-depot", force = "lp-serenity", pos = {42.6, 132}}
build[#build + 1] = {name = "steel-chest", force = "player", pos = {46.7, 132}}
shots[#shots + 1] = {name = "22-kh-depot", tick = 284, pos = {44.0, 130.8}, zoom = 2.27, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-launchpad", force = "lp-serenity", pos = {82.8, 132}}
build[#build + 1] = {name = "rocket-silo", force = "player", pos = {93.2, 132}}
shots[#shots + 1] = {name = "23-kh-launchpad", tick = 286, pos = {88.0, 129.1}, zoom = 1.19, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-mortar", force = "lp-serenity", pos = {129.8, 132}}
build[#build + 1] = {name = "artillery-turret", force = "player", pos = {133.8, 132}}
shots[#shots + 1] = {name = "24-kh-mortar", tick = 288, pos = {132.0, 131.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-howitzer", force = "lp-serenity", pos = {173.8, 132}}
build[#build + 1] = {name = "artillery-turret", force = "player", pos = {178.2, 132}}
shots[#shots + 1] = {name = "25-kh-howitzer", tick = 290, pos = {176.0, 131.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-dome-projector", force = "lp-serenity", pos = {217.3, 132}}
build[#build + 1] = {name = "tesla-turret", force = "player", pos = {222.2, 132}}
shots[#shots + 1] = {name = "26-kh-dome-projector", tick = 292, pos = {220.0, 130.8}, zoom = 2.27, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-orbital-relay", force = "lp-serenity", pos = {261.8, 132}}
build[#build + 1] = {name = "radar", force = "player", pos = {266.2, 132}}
shots[#shots + 1] = {name = "27-kh-orbital-relay", tick = 294, pos = {264.0, 131.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-pacifier", force = "lp-serenity", pos = {-2.2, 176}}
build[#build + 1] = {name = "radar", force = "player", pos = {2.9, 176}}
shots[#shots + 1] = {name = "28-kh-pacifier", tick = 296, pos = {0.0, 174.7}, zoom = 2.12, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-jammer", force = "lp-serenity", pos = {42.4, 176}}
build[#build + 1] = {name = "big-electric-pole", force = "player", pos = {45.6, 176}}
shots[#shots + 1] = {name = "29-kh-jammer", tick = 298, pos = {44.0, 175.5}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-uplink", force = "lp-serenity", pos = {85.8, 176}}
build[#build + 1] = {name = "radar", force = "player", pos = {91.9, 176}}
shots[#shots + 1] = {name = "30-kh-uplink", tick = 300, pos = {88.0, 174.0}, zoom = 1.58, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-line-lab", force = "lp-serenity", pos = {129.8, 176}}
build[#build + 1] = {name = "lab", force = "player", pos = {134.9, 176}}
shots[#shots + 1] = {name = "31-kh-line-lab", tick = 302, pos = {132.0, 174.7}, zoom = 2.12, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-optics-lab", force = "lp-serenity", pos = {173.8, 176}}
build[#build + 1] = {name = "lab", force = "player", pos = {178.9, 176}}
shots[#shots + 1] = {name = "32-kh-optics-lab", tick = 304, pos = {176.0, 174.7}, zoom = 2.12, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-fabricator", force = "lp-grubstake", pos = {217.8, 176}}
build[#build + 1] = {name = "assembling-machine-2", force = "player", pos = {222.2, 176}}
shots[#shots + 1] = {name = "33-gs-fabricator", tick = 306, pos = {220.0, 175.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-generator", force = "lp-grubstake", pos = {262.1, 176}}
build[#build + 1] = {name = "accumulator", force = "player", pos = {265.9, 176}}
shots[#shots + 1] = {name = "34-gs-generator", tick = 308, pos = {264.0, 175.4}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-radar", force = "lp-grubstake", pos = {-2.2, 220}}
build[#build + 1] = {name = "radar", force = "player", pos = {2.2, 220}}
shots[#shots + 1] = {name = "35-gs-radar", tick = 310, pos = {-0.0, 219.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-drill", force = "lp-grubstake", pos = {41.6, 220}}
build[#build + 1] = {name = "electric-mining-drill", force = "player", pos = {46.4, 220}}
shots[#shots + 1] = {name = "36-gs-drill", tick = 312, pos = {44.0, 219.1}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-turret", force = "lp-grubstake", pos = {86.3, 220}}
build[#build + 1] = {name = "gun-turret", force = "player", pos = {89.7, 220}}
shots[#shots + 1] = {name = "37-gs-turret", tick = 314, pos = {88.0, 219.5}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-scrap-cannon", force = "lp-grubstake", pos = {130.3, 220}}
build[#build + 1] = {name = "gun-turret", force = "player", pos = {133.7, 220}}
shots[#shots + 1] = {name = "38-gs-scrap-cannon", tick = 316, pos = {132.0, 219.5}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-flamer", force = "lp-grubstake", pos = {173.8, 220}}
build[#build + 1] = {name = "flamethrower-turret", force = "player", pos = {178.2, 220}}
shots[#shots + 1] = {name = "39-gs-flamer", tick = 318, pos = {176.0, 219.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-pylon", force = "lp-grubstake", pos = {218.8, 220}}
build[#build + 1] = {name = "medium-electric-pole", force = "player", pos = {221.2, 220}}
shots[#shots + 1] = {name = "40-gs-pylon", tick = 320, pos = {220.0, 219.9}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-depot", force = "lp-grubstake", pos = {262.6, 220}}
build[#build + 1] = {name = "steel-chest", force = "player", pos = {266.7, 220}}
shots[#shots + 1] = {name = "41-gs-depot", tick = 322, pos = {264.0, 218.8}, zoom = 2.27, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-launchpad", force = "lp-grubstake", pos = {-5.2, 264}}
build[#build + 1] = {name = "rocket-silo", force = "player", pos = {5.2, 264}}
shots[#shots + 1] = {name = "42-gs-launchpad", tick = 324, pos = {0.0, 261.1}, zoom = 1.19, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-mortar", force = "lp-grubstake", pos = {41.8, 264}}
build[#build + 1] = {name = "artillery-turret", force = "player", pos = {45.8, 264}}
shots[#shots + 1] = {name = "43-gs-mortar", tick = 326, pos = {44.0, 263.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-howitzer", force = "lp-grubstake", pos = {85.8, 264}}
build[#build + 1] = {name = "artillery-turret", force = "player", pos = {90.2, 264}}
shots[#shots + 1] = {name = "44-gs-howitzer", tick = 328, pos = {88.0, 263.2}, zoom = 2.40, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-pacifier", force = "lp-grubstake", pos = {129.8, 264}}
build[#build + 1] = {name = "radar", force = "player", pos = {134.9, 264}}
shots[#shots + 1] = {name = "45-gs-pacifier", tick = 330, pos = {132.0, 262.7}, zoom = 2.12, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-uplink", force = "lp-grubstake", pos = {173.8, 264}}
build[#build + 1] = {name = "radar", force = "player", pos = {179.9, 264}}
shots[#shots + 1] = {name = "46-gs-uplink", tick = 332, pos = {176.0, 262.0}, zoom = 1.58, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-line-lab", force = "lp-grubstake", pos = {217.8, 264}}
build[#build + 1] = {name = "lab", force = "player", pos = {222.9, 264}}
shots[#shots + 1] = {name = "47-gs-line-lab", tick = 334, pos = {220.0, 262.7}, zoom = 2.12, daytime = 0.05, hide_clouds = true}
build[#build + 1] = {name = "lp-grubstake-optics-lab", force = "lp-grubstake", pos = {261.8, 264}}
build[#build + 1] = {name = "lab", force = "player", pos = {266.9, 264}}
shots[#shots + 1] = {name = "48-gs-optics-lab", tick = 336, pos = {264.0, 262.7}, zoom = 2.12, daytime = 0.05, hide_clouds = true}
return {name = "rating", pad = {-24, -24, 308, 308}, tile = "grass-1", build = build, shots = shots,
  resolution = {1280, 760}}
