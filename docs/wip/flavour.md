# Flavour lines removed from the game text (2026-11-02)

Raw material for a future player manual. Each line is the locale key (or Lua location) and the text it carried
before the locale audit (`docs/wip/locale-audit.md`) replaced it with plain, vanilla-register text. `__1__` is the
faction's icon and name, `__2__` a map position unless noted. Spelling and number-only changes are not listed.

## Kessler-Hayashi

Motto (`shared.lua`, shown in quotes after every landing by `lp.landed`): "Please remain behind the line."

| Key | Old text |
|---|---|
| lp.node-optics | \_\_1\_\_ has recalibrated its optics (level \_\_2\_\_). Please remain behind the line. |
| lp.node-railguns | \_\_1\_\_ has wound heavier coils for its railgunners (level \_\_2\_\_). |
| lp.node-hardened | \_\_1\_\_ has taught its siege crews to dig in. |
| lp.node-aegis | \_\_1\_\_ has fielded heavy tanks. Their rail cannons go through any armour. |
| lp.node-jammer | \_\_1\_\_ raises a jamming mast with its siege guns: your robots fall in its arcs. |
| lp.node-tesla | \_\_1\_\_ has fielded lightning tanks. Your turrets go dark where their lightning lands. |
| lp.perimeter | \_\_1\_\_ has extended its perimeter at \_\_2\_\_ to \_\_3\_\_ tiles. Please remain behind the line. |
| lp.perimeter-warning | \_\_1\_\_ will extend its perimeter past your \_\_2\_\_ at \_\_3\_\_ within ten minutes. Please remain behind the line. |
| lp.hq-down-serenity | Kessler-Hayashi regrets the closure of its regional office at \_\_1\_\_. Please remain behind the line. |
| lp.border-accepted | \_\_1\_\_ acknowledges your border at \_\_2\_\_. Its line will hold there while nothing of yours stands on its side. |
| lp.border-refused | \_\_1\_\_ does not treat with enemies. A truce bought at its invoice post opens talks. |
| lp.border-inside | \_\_1\_\_ already claims this ground: a stake here is not a border. |
| lp.border-none | No Kessler-Hayashi camp within reach to treat with. |
| lp.invoice | \_\_1\_\_ invoice: [item=\_\_2\_\_] \_\_3\_\_ owed. Paid off: a truce. |
| lp.line-held | \_\_1\_\_'s line is held at \_\_2\_\_: it lost \_\_3\_\_ drones building a post there and has given it up. |
| lp.relief-column | \_\_1\_\_: a relief detachment is on its way to the perimeter site at \_\_2\_\_. |
| lp.orbital | \_\_1\_\_ is shelling the nests round its landing site at \_\_2\_\_ from orbit. |
| entity-description.lp-laser-drone | Kessler-Hayashi's flier: armoured and few, with a laser beam. Small arms barely scratch it; flak and rockets bring it down. |
| entity-description.lp-skyguard | Kessler-Hayashi's answer to fliers: a long laser that tracks what flies, and a weak shot at the ground. |
| entity-description.lp-invoice-post | Kessler-Hayashi bills you here for the biter waves your pollution sends through its ground. Pay in circuits, modules, steel and the like, by their worth (other items stay). Paid off, it buys a truce: no attacks, and its line holds, for a minute per 10 paid (10 to 60). |
| entity-description.lp-jammer | Downs construction and logistic robots in its arcs, so what its siege breaks stays broken. Destroy the mast, or keep your roboports out of its reach. |
| technology-description.lp-orbital-strike | Kessler-Hayashi's orbital beacon, taken apart: a beacon that, charged on your power, calls Kessler-Hayashi's own barrage on every nest and enemy building within 60 tiles, and burns out. Research by disassembling an orbital beacon, from a Kessler-Hayashi lander or uplink. |
| technology-description.lp-rail-rifle | Kessler-Hayashi's railgun, taken apart: a rifle whose slug pierces a 30-tile line. Research by disassembling two rail coils, from Kessler-Hayashi's railgunners. |
| technology-description.lp-cluster-shells | Kessler-Hayashi's cluster fuze, taken apart: your artillery shells burst into bomblets round the impact. Research by disassembling three cluster fuzes, taken from Kessler-Hayashi's mortars and howitzers. |
| mod-setting-description.lp-serenity-strength | How much army Kessler-Hayashi fields: its camps' unit cap. |
| mod-setting-description.lp-serenity-aggression | How soon Kessler-Hayashi acts: its ladder's climb, the gaps between its operations, answers and heists, and how long it keeps trying before standing down. |

## Grubstake

Motto (`shared.lua`, shown in quotes after every landing by `lp.landed`): "Resources in the right hands."
Full name in chat, entity suffixes and tile names until now: "Grubstake Inc."

| Key | Old text |
|---|---|
| lp.node-handloads | \_\_1\_\_ has started hand-loading its shells (level \_\_2\_\_). |
| lp.node-scrap-plating | \_\_1\_\_ is bolting scrap plating onto its shotgun hands and buggies. |
| lp.node-sapper | \_\_1\_\_ is handing out dynamite. Its sappers throw it at whatever stands in the way. |
| lp.node-slug | \_\_1\_\_ has bolted slug guns onto its buggies. Mind your vehicles. |
| lp.node-salvage | \_\_1\_\_ has bought the salvage rights to everything it breaks. Your losses fund its research. |
| lp.node-prospector | \_\_1\_\_ has trained its prospectors' eye: it strips further from your turrets and runs sooner. |
| lp.node-dozer | \_\_1\_\_ has bought a Dozer. Your walls are now a suggestion. |
| lp.node-scavenger | \_\_1\_\_ is building bomb drones. They are looking for your artillery. |
| lp.node-scorcher | \_\_1\_\_ has welded flamethrowers onto old tank hulls. Mind your walls. |
| lp.node-asbestos | \_\_1\_\_ has found a supply of asbestos suits. Its shotgun hands and buggies no longer mind the fire. |
| lp.claim | \_\_1\_\_ has registered a claim on the deposit at \_\_2\_\_. Resources in the right hands. |
| lp.claim-outpost | \_\_1\_\_ has opened a permanent recovery site on the deposit at \_\_2\_\_. Thank you for your cooperation. |
| lp.hq-down-grubstake | Grubstake Inc. has concluded its recovery operations at \_\_1\_\_. Thank you for your cooperation. |
| lp.relief-pod | \_\_1\_\_: contractors arrived at the claim at \_\_2\_\_. Hazard pay approved. |
| lp.rig | \_\_1\_\_ is drilling a tunnel from \_\_2\_\_. Destroy the rig within two and a half minutes or its crew comes up inside your walls. |
| lp.prospect | \_\_1\_\_ has reassigned the mineral rights to the ore at \_\_2\_\_. Drill it or stake it within ten minutes, or it will be claimed. |
| lp.road-lost | A \_\_1\_\_ ore truck was destroyed at \_\_2\_\_. Its expansion is delayed about \_\_3\_\_ minutes. |
| lp.claim-lapsed | \_\_1\_\_'s claim at \_\_2\_\_ has lapsed: no ore went home. Its drills are there to take. |
| `scripts/prospect.lua` map tag | Mineral rights reassigned |
| entity-description.lp-harrier | Grubstake's flier: scrap and a gun, weak and cheap, sent in numbers over your walls. |
| entity-description.lp-scavenger | Grubstake's flier with a charge in it: it flies at your artillery, mortars and radars and blows up on them. Shoot it down before it arrives. |
| entity-description.lp-flak-buggy | Grubstake's answer to fliers: scrap flak bursting in the air, and a weak splash on the ground. |
| entity-description.lp-skim-yard | Where Grubstake keeps what it skimmed. Destroyed, what it holds spills. |
| entity-description.lp-claim-stake | Mineral rights reassigned, driven out by a Grubstake truck. Unworked ground is claimed when the lamp runs out (it turns red near the end). Drill or stake the patch, or pull this down, and the claim is off. |
| technology-description.lp-pact-breaker | Grubstake's pacifier crystal, taken apart: set inside a Grubstake claim, it jams its pact with the biters for 3 minutes. Research by disassembling a pacifier crystal. |
| technology-description.lp-claim-marker | Grubstake's pacifier crystal, taken apart: Grubstake reads your buildings within 40 tiles of the marker as its own claim and leaves them alone. Research by disassembling two pacifier crystals. |
| technology-description.lp-pheromone-bait | Grubstake's gland, taken apart: a bait that calls the idle biters round it to attack whatever they meet there. Grubstake's pact keeps them off Grubstake. Research by disassembling three pheromone glands, from Grubstake's pacifier antennas and Synthexis incubators. |
| mod-setting-description.lp-grubstake-strength | How much army Grubstake fields: its camps' unit cap. |
| mod-setting-description.lp-grubstake-aggression | How soon Grubstake acts: its ladder's climb, the gaps between its operations, answers and heists, and how long it keeps trying before standing down. |

## Synthexis

| Key | Old text |
|---|---|
| lp.biotech-bursters | Synthexis has learned to breed big bursters: its waves were held at your walls, and it will bring siege engines next. |
| lp.biotech-landed | Synthexis has seeded a culture in the nests at \_\_1\_\_. Engineered to adapt. |
| entity-description.lp-pen | A biter nest taken and fed by Synthexis. What it breeds is Synthexis's, not the wild nests'. Hit, it calls its wave home; killed, it drops a pheromone gland. |
| entity-description.lp-bred-cinder | A fast, frail biter swollen with acid. It runs at your line and bursts there, and wherever it dies the ground splits and erupts, breaking walls and turrets round it. Kill it at range, before it reaches your wall. |
| entity-description.lp-bred-big-burster | A behemoth swollen with acid, bred to cross a turret line. It walks through the fire at the nearest turret and bursts there, and the eruption breaks every turret round it. Focus it, rocket it or shell it before it arrives; a wall that holds it short of the turrets takes the blast. |
| entity-description.lp-bred-scout | It circles a defence before a wave comes: the warning. Kill it and the next scout there loops wider; the wave comes all the same. |
| entity-description.lp-bred-carrier | A mature culture's seed, walking with an escort to a wild nest field where a new culture will begin. Kill it on the way and the culture has paid for nothing. |
| entity-description.lp-bred-spore | Synthexis's answer to fliers: spit that bursts into spores where it lands, aloft as well. Weak against the ground. |
| entity-description.lp-bred-stomper | A bred pentapod that steps over your wall and stomps what stands inside. Rockets, slugs, heavy tanks, fliers and artillery bring it down; rifles barely do. |
| entity-description.lp-biochamber | Where Synthexis feeds an incubator. While it works, the incubator breeds. |
| entity-description.lp-clinic | Where Synthexis improves its breeds. While it stands they grow stronger; destroyed, its incubators breed only small and medium biters until a new one lands. |
| entity-description.lp-runt | Thrown at your wall to see which turrets fire. Where one stays silent, the herd comes in. |
| entity-description.lp-sweeper | Sent into your minefields ahead of a siege. It bursts among the mines and clears a lane for the herd. |
| entity-description.lp-bred | Bred by Synthexis in an incubator and marked in its colours. The wild biters leave it alone, and it leaves them alone. |
| mod-setting-description.lp-biotech-strength | How much Synthexis breeds: the biomass it earns (from the pollution its creep drinks, its incubators' trickle and its pod). |

## Any faction

| Key | Old text |
|---|---|
| lp.signs | Radar contact: the wreck of an unknown craft at \_\_1\_\_. Something is out there. |
| lp.survey | A survey party has come down at \_\_1\_\_. It is mapping the ore. It will not stay long. |
| lp.survey-destroyed | The survey party at \_\_1\_\_ is destroyed. Whoever sent it will take longer to come; its command core is in the wreckage. |
| lp.survey-left | The survey party at \_\_1\_\_ has left. Its owners know where the ore is now. |
| lp.develop | \_\_1\_\_ has expanded its capabilities: \_\_2\_\_. |
| lp.consolidating | \_\_1\_\_ is consolidating its holdings in this region. A regional headquarters will follow. |
| lp.headquarters | \_\_1\_\_ has established its regional headquarters at \_\_2\_\_. |
| lp.landed | \_\_1\_\_ has landed at \_\_2\_\_. "\_\_3\_\_" (\_\_3\_\_ the faction's motto) |
| lp.landing-cleared | \_\_1\_\_'s lander burned a clearing at \_\_2\_\_: \_\_3\_\_ nests and worms destroyed. |
| lp.grudge | \_\_1\_\_ will remember this. Its next landing will come with a double escort, ready for a siege. |
| lp.grudge-landed | \_\_1\_\_ has landed at \_\_2\_\_, and it has not forgotten. |
| lp.stood-down | \_\_1\_\_: the settlement at \_\_2\_\_ has stood down. It keeps to itself for now. |
| lp.late-gate | \_\_1\_\_ has taken an interest in your progress. Its first landing is due within five minutes. |
| lp.fallen | \_\_1\_\_ has lost \_\_3\_\_ at \_\_2\_\_. Its outposts are there for the taking, and its ruins can be salvaged. (\_\_3\_\_ the base's name) |
| lp.uplink-down | The uplink has fallen. No more landings will come, and the faction can grow no stronger. (dead key, removed) |
| lp.tap | \_\_1\_\_ has run a power line to your pole at \_\_2\_\_ and is drawing your power. Cut the line or break the tap. (dead key, removed) |
| `scripts/faction.lua` CAP_NOTICE | harriers / pickets that report what they see / siege operations |
| entity-description.lp-muster-point | Trooper, breacher and tank orders put in it become units here, sent to the nearest rally beacon. A barracks wired with signal P keeps its orders as items for you to carry here: by train, belt or robot. |
| entity-description.lp-threat-scanner | Counts the corporations' units within 64 tiles, by kind, each second: a signal for each kind, a total for each corporation, the building crews apart, and the biters. Wire it to deciders and a rally beacon. |
| technology-description.lp-command-bandwidth | More command relays carry your units. The first level unlocks barracks and grants a command core; more come from the Landing Party's wreckage. |
| mod-setting-description.lp-chat-notices | Tell the corporations' moves in chat and with alerts (for debugging). Off, they show in the world only; a corporation's first landing and a lost settlement are always told. |
| mod-description.landing-party | A rival machine faction lands and builds a factory of its own. Prototype. |
