# Locale audit: Landing Party 0.2.139 (2026-11-02)

Status: applied in 0.2.140 (DESIGN.md findings, "Locale audit applied"); the strings added up to 0.2.212 brought to it
in 0.2.213 ("Locale pass, 0.2.213"), and the rules a pattern can see are linted since (`scripts/lint_names.py`).

Sources read: `landing-party/locale/en/locale.cfg` (331 strings), every `{"lp.…"}` key built in Lua (including the
dynamic ones: `"lp.node-" .. id`, `"lp.plate-" .. plate`, `"lp.withdrawing-" .. corp`, `"lp.hq-down-" .. corp`), and
the literal English in `draw_text`, `add_chart_tag`, `.text =`, `game.print` and `add_custom_alert` calls (20 strings).
`scripts/dev.lua` (admin dev tools) and the trace readout are left out: developer-facing. Register compared against
`data/base/locale/en/base.cfg`, `data/core/locale/en/core.cfg` and `data/space-age/locale/en/space-age.cfg`.

## 1. Verdict

Names are close to vanilla: short, sentence case, plain nouns ("Strip drill", "Rally beacon", "Shock trooper").
Everything longer than a name is not. The messages and descriptions read like a narrator: corporate euphemism
("has reassigned the mineral rights", "regrets the closure of its regional office"), quips ("Your walls are now a
suggestion", "Hazard pay approved"), slogans stapled onto unrelated notices ("Please remain behind the line." five
times, "Thank you for your cooperation." twice), and dramatic tags ("Something is out there.", "it has not
forgotten"). The entity, technology and mod-setting descriptions explain the design to the player: counter-advice,
internal terms ("ladder's climb", "biomass", "bandwidth"), how the research trigger works, all in two or three clauses
joined by colons and semicolons. Vanilla descriptions say what a thing does in one sentence, usually under 80
characters ("Fires a stream of burning liquid at enemies."). The mod's average entity description is about 200.

Smaller, systematic issues:
- **British spelling** (armour, armoury, defence, colours, "round" for around). Vanilla is US English throughout
  (28 "armor", 0 "armour" in base.cfg).
- **Numbers as words** ("ten minutes", "two and a half minutes", "five minutes"). Vanilla writes digits.
- **"Nest"** for what vanilla calls a spawner or an enemy base. "Nest" does not appear in vanilla's locale at all.
- **Unlocalised English in Lua**: standing labels, siege progress text, map tags, the level-up capability list, the
  tile names, the corporation names and mottos. None of it can be translated, and the labels are lowercase.
- **Two dead keys**: `lp.tap` and `lp.uplink-down` are never referenced.

## 2. Problem strings

Severity: **A** voice problem a player will notice (quip, slogan, flourish, euphemism, design lecture); **B** too
long or explains mechanics; **C** spelling, numbers, term or capitalisation.

### 2.1 Messages (`[lp]`)

| Key | Current | Problem | Proposed |
|---|---|---|---|
| biotech-bursters | Synthexis has learned to breed big bursters: its waves were held at your walls, and it will bring siege engines next. | A. Explains the AI's reasoning; "siege engines" is wrong (it brings big bursters). | Synthexis now breeds big bursters. |
| signs | Radar contact: the wreck of an unknown craft at \_\_1\_\_. Something is out there. | A. Ominous tag line. | Radar has found a wrecked craft at \_\_1\_\_. |
| survey | A survey party has come down at \_\_1\_\_. It is mapping the ore. It will not stay long. | A. Three clipped sentences, narrator voice. | A survey party has landed at \_\_1\_\_ to map the ore. |
| survey-destroyed | The survey party at \_\_1\_\_ is destroyed. Whoever sent it will take longer to come; its command core is in the wreckage. | B. "Whoever sent it", semicolon chain. | Survey party destroyed at \_\_1\_\_. It dropped a command core. |
| survey-left | The survey party at \_\_1\_\_ has left. Its owners know where the ore is now. | A. Ominous tag line. | The survey party at \_\_1\_\_ has left. |
| develop | \_\_1\_\_ has expanded its capabilities: \_\_2\_\_. | A. Corporate speak; \_\_2\_\_ is unlocalised Lua text (see 2.6). | \_\_1\_\_ has unlocked \_\_2\_\_. |
| plate-physical | armoured | C. US spelling. | armored |
| node-optics | \_\_1\_\_ has recalibrated its optics (level \_\_2\_\_). Please remain behind the line. | A. Slogan appended; "recalibrated its optics" for a damage upgrade. | \_\_1\_\_ has researched laser weapons damage \_\_2\_\_. |
| node-railguns | \_\_1\_\_ has wound heavier coils for its railgunners (level \_\_2\_\_). | B. Flavor in place of the effect. | \_\_1\_\_ has researched railgun damage \_\_2\_\_. |
| node-warden | \_\_1\_\_ has issued heavier armour to its laser troopers. | C. Spelling. | \_\_1\_\_'s laser troopers now have heavier armor. |
| node-handloads | \_\_1\_\_ has started hand-loading its shells (level \_\_2\_\_). | B. Flavor in place of the effect (bullets and shotgun shells). | \_\_1\_\_ has researched physical projectile damage \_\_2\_\_. |
| node-scrap-plating | \_\_1\_\_ is bolting scrap plating onto its shotgun hands and buggies. | B. Flavor verb. | \_\_1\_\_'s shotgun hands and buggies now have scrap armor. |
| node-sapper | \_\_1\_\_ is handing out dynamite. Its sappers throw it at whatever stands in the way. | B. Vague. | \_\_1\_\_ now fields dynamite sappers. They throw explosives at walls. |
| node-slug | \_\_1\_\_ has bolted slug guns onto its buggies. Mind your vehicles. | A. "Mind your vehicles." | \_\_1\_\_'s buggies now carry slug guns, effective against vehicles. |
| node-salvage | \_\_1\_\_ has bought the salvage rights to everything it breaks. Your losses fund its research. | A. Corporate quip. | \_\_1\_\_ now salvages what it destroys to fund its research. |
| node-prospector | \_\_1\_\_ has trained its prospectors' eye: it strips further from your turrets and runs sooner. | B. Colon construction, "trained its prospectors' eye". | \_\_1\_\_'s strip miners now stay further from your turrets. |
| node-hardened | \_\_1\_\_ has taught its siege crews to dig in. | B. Does not say the effect. | \_\_1\_\_'s siege mortars now take less damage. |
| node-aegis | \_\_1\_\_ has fielded heavy tanks. Their rail cannons go through any armour. | C. Spelling; "go through any" overstates. | \_\_1\_\_ now fields heavy tanks. Their rail cannons pierce armor. |
| node-dozer | \_\_1\_\_ has bought a Dozer. Your walls are now a suggestion. | A. Quip; "Dozer" capitalised mid-sentence. | \_\_1\_\_ now fields a dozer. It breaks through walls. |
| node-scavenger | \_\_1\_\_ is building bomb drones. They are looking for your artillery. | A. Menacing tone; incomplete (they also hit mortars and radars). | \_\_1\_\_ now fields bomb drones. They target artillery and radars. |
| node-jammer | \_\_1\_\_ raises a jamming mast with its siege guns: your robots fall in its arcs. | A. "fall in its arcs". | \_\_1\_\_'s sieges now bring a jamming mast that downs robots. |
| node-counter | \_\_1\_\_ sends shock troopers with its siege crews when your artillery is in reach. | C. "in reach" for vanilla's "in range". | \_\_1\_\_'s sieges now bring shock troopers when your artillery is in range. |
| node-tesla | \_\_1\_\_ has fielded lightning tanks. Your turrets go dark where their lightning lands. | A. "go dark". | \_\_1\_\_ now fields lightning tanks. Their lightning disables turrets. |
| node-scorcher | \_\_1\_\_ has welded flamethrowers onto old tank hulls. Mind your walls. | A. "Mind your walls." | \_\_1\_\_ now fields flame tanks. |
| node-asbestos | \_\_1\_\_ has found a supply of asbestos suits. Its shotgun hands and buggies no longer mind the fire. | A. Whimsy ("no longer mind"). | \_\_1\_\_'s shotgun hands and buggies now resist fire. |
| perimeter | \_\_1\_\_ has extended its perimeter at \_\_2\_\_ to \_\_3\_\_ tiles. Please remain behind the line. | A. Slogan appended. | \_\_1\_\_ has extended its perimeter at \_\_2\_\_ to \_\_3\_\_ tiles. |
| perimeter-warning | \_\_1\_\_ will extend its perimeter past your \_\_2\_\_ at \_\_3\_\_ within ten minutes. Please remain behind the line. | A. Slogan; C. number as word. | \_\_1\_\_ will extend its perimeter past your \_\_2\_\_ at \_\_3\_\_ in 10 minutes. |
| claim | \_\_1\_\_ has registered a claim on the deposit at \_\_2\_\_. Resources in the right hands. | A. Slogan; "registered a claim on" euphemism. | \_\_1\_\_ has claimed the ore at \_\_2\_\_. |
| claim-outpost | \_\_1\_\_ has opened a permanent recovery site on the deposit at \_\_2\_\_. Thank you for your cooperation. | A. Slogan; euphemism. | \_\_1\_\_ has built a permanent mine on the ore at \_\_2\_\_. |
| consolidating | \_\_1\_\_ is consolidating its holdings in this region. A regional headquarters will follow. | A. Corporate speak. | \_\_1\_\_ is preparing to build a headquarters. |
| headquarters | \_\_1\_\_ has established its regional headquarters at \_\_2\_\_. | C. "established its regional". | \_\_1\_\_ has built a headquarters at \_\_2\_\_. |
| hq-down-serenity | Kessler-Hayashi regrets the closure of its regional office at \_\_1\_\_. Please remain behind the line. | A. Euphemism plus slogan; the player destroyed it. Name typed in place of \_\_1\_\_. | Kessler-Hayashi's headquarters at \_\_1\_\_ is destroyed. |
| hq-down-grubstake | Grubstake Inc. has concluded its recovery operations at \_\_1\_\_. Thank you for your cooperation. | A. Euphemism plus slogan. | Grubstake's headquarters at \_\_1\_\_ is destroyed. |
| alert-siege | \_\_1\_\_ siege: a mortar is shelling you | C. Alerts do not address "you"; vanilla alert style is a short statement. | \_\_1\_\_ mortar is shelling your base |
| landed | \_\_1\_\_ has landed at \_\_2\_\_. "\_\_3\_\_" | A. The motto in quotes after every landing. | \_\_1\_\_ has landed at \_\_2\_\_. |
| biotech-landed | Synthexis has seeded a culture in the nests at \_\_1\_\_. Engineered to adapt. | A. Marketing tag line. | Synthexis has taken over the spawners at \_\_1\_\_. |
| landing-cleared | \_\_1\_\_'s lander burned a clearing at \_\_2\_\_: \_\_3\_\_ nests and worms destroyed. | C. "nests". | \_\_1\_\_'s landing destroyed \_\_3\_\_ spawners and worms at \_\_2\_\_. |
| grudge | \_\_1\_\_ will remember this. Its next landing will come with a double escort, ready for a siege. | A. Dramatic; explains the mechanic. | \_\_1\_\_'s next landing will bring a larger escort. |
| grudge-landed | \_\_1\_\_ has landed at \_\_2\_\_, and it has not forgotten. | A. Dramatic. | \_\_1\_\_ has landed at \_\_2\_\_ with a larger escort. |
| relief-pod | \_\_1\_\_: contractors arrived at the claim at \_\_2\_\_. Hazard pay approved. | A. Quip. | \_\_1\_\_: reinforcements have landed at the claim at \_\_2\_\_. |
| rig | \_\_1\_\_ is drilling a tunnel from \_\_2\_\_. Destroy the rig within two and a half minutes or its crew comes up inside your walls. | B. Long; C. number as words. | \_\_1\_\_ is tunneling from \_\_2\_\_. Destroy the rig within 150 seconds. |
| prospect | \_\_1\_\_ has reassigned the mineral rights to the ore at \_\_2\_\_. Drill it or stake it within ten minutes, or it will be claimed. | A. Corporate euphemism; C. number as word. | \_\_1\_\_ will claim the ore at \_\_2\_\_ in 10 minutes unless you mine it. |
| border-accepted | \_\_1\_\_ acknowledges your border at \_\_2\_\_. Its line will hold there while nothing of yours stands on its side. | B. Long, literary ("nothing of yours stands"). | \_\_1\_\_ accepts your border at \_\_2\_\_. Do not build past it. |
| border-refused | \_\_1\_\_ does not treat with enemies. A truce bought at its invoice post opens talks. | A. Archaic "treat with"; "opens talks". | \_\_1\_\_ needs a truce first. Pay its invoice post. |
| border-inside | \_\_1\_\_ already claims this ground: a stake here is not a border. | B. Colon explanation. | This ground is already claimed by \_\_1\_\_. |
| border-none | No Kessler-Hayashi camp within reach to treat with. | A. "treat with"; C. "within reach", name typed. | No Kessler-Hayashi base in range. |
| invoice | \_\_1\_\_ invoice: [item=\_\_2\_\_] \_\_3\_\_ owed. Paid off: a truce. | B. The second clause belongs in the post's description. | \_\_1\_\_ invoice: [item=\_\_2\_\_] \_\_3\_\_ owed |
| invoice-paid | \_\_1\_\_: invoice paid; a truce of \_\_2\_\_ minutes. | C. Semicolon, noun phrase. | \_\_1\_\_: invoice paid. Truce for \_\_2\_\_ minutes. |
| road-lost | A \_\_1\_\_ ore truck was destroyed at \_\_2\_\_. Its expansion is delayed about \_\_3\_\_ minutes. | C. Hedge "about"; "Its" has no clear owner. | \_\_1\_\_ ore truck destroyed at \_\_2\_\_. Expansion delayed by \_\_3\_\_ minutes. |
| claim-lapsed | \_\_1\_\_'s claim at \_\_2\_\_ has lapsed: no ore went home. Its drills are there to take. | A. "went home", "there to take". | \_\_1\_\_'s claim at \_\_2\_\_ has lapsed. Its drills can be mined. |
| line-held | \_\_1\_\_'s line is held at \_\_2\_\_: it lost \_\_3\_\_ drones building a post there and has given it up. | B. Colon chain. | \_\_1\_\_ has given up building a post at \_\_2\_\_ after losing \_\_3\_\_ drones. |
| stood-down | \_\_1\_\_: the settlement at \_\_2\_\_ has stood down. It keeps to itself for now. | A. Hedge "for now"; military idiom. | \_\_1\_\_: the base at \_\_2\_\_ has stopped attacking. |
| late-gate | \_\_1\_\_ has taken an interest in your progress. Its first landing is due within five minutes. | A. Ominous flourish; C. number as word. | \_\_1\_\_ will land within 5 minutes. |
| orbital | \_\_1\_\_ is shelling the nests round its landing site at \_\_2\_\_ from orbit. | C. "nests", "round". | \_\_1\_\_ is shelling the spawners around its landing site at \_\_2\_\_. |
| dome-alert | \_\_1\_\_'s shield is catching your artillery shells | C. "catching". | \_\_1\_\_'s shield is blocking your artillery shells |
| relief-column | \_\_1\_\_: a relief detachment is on its way to the perimeter site at \_\_2\_\_. | C. Third name for reinforcements. | \_\_1\_\_: reinforcements are on the way to \_\_2\_\_. |
| fallen | \_\_1\_\_ has lost \_\_3\_\_ at \_\_2\_\_. Its outposts are there for the taking, and its ruins can be salvaged. | A. "there for the taking". | \_\_1\_\_ has lost \_\_3\_\_ at \_\_2\_\_. Its outposts can be captured. |
| uplink-down | The uplink has fallen. No more landings will come, and the faction can grow no stronger. | A. Dramatic; also unreferenced in Lua (dead key). | Uplink destroyed. No more landings will come. |
| tap | \_\_1\_\_ has run a power line to your pole at \_\_2\_\_ and is drawing your power. Cut the line or break the tap. | Unreferenced in Lua (dead key). Text is acceptable. | \_\_1\_\_ is drawing power from your pole at \_\_2\_\_. |
| command-land | Land a Landing Party base this many tiles east of you (default 60). | C. Vanilla command help is "\<args\> - Does X." | \<tiles\> - Lands a settlement east of you (default 60). |

### 2.2 Entity and item names

| Key | Current | Problem | Proposed |
|---|---|---|---|
| entity-name.lp-line-lab | Line armoury | C. Spelling; obscure. | Armory |
| entity-name.lp-belt | Conveyor | C. Vanilla term is "Transport belt". | Transport belt |
| entity-name.lp-infantry | Drone infantry | C. Shown only where no corp rename applies; every other infantry is a "trooper". | Drone trooper |
| entity-name.lp-uplink | Headquarters uplink | C. Messages call it "the uplink"; the HQ is a separate notion. | Uplink |
| item-name.lp-fuze-schematic (and gland, coil, beacon, crystal) | Cluster fuze, disassembled | C. Comma-postfix naming has no vanilla pattern. | Cluster fuze parts |

### 2.3 Entity descriptions

| Key | Current | Problem | Proposed |
|---|---|---|---|
| lp-pen | A biter nest taken and fed by Synthexis. What it breeds is Synthexis's, not the wild nests'. Hit, it calls its wave home; killed, it drops a pheromone gland. | B. Three clauses, inverted syntax ("Hit, it calls…"). | A biter spawner taken over by Synthexis. Drops a pheromone gland. |
| lp-bred-cinder | A fast, frail biter swollen with acid. It runs at your line and bursts there, and wherever it dies the ground splits and erupts, breaking walls and turrets round it. Kill it at range, before it reaches your wall. | B. 210 characters; advice to the player. | A fast biter that bursts on death, damaging nearby walls and turrets. |
| lp-bred-big-burster | A behemoth swollen with acid, bred to cross a turret line. It walks through the fire at the nearest turret and bursts there, and the eruption breaks every turret round it. Focus it, rocket it or shell it before it arrives; a wall that holds it short of the turrets takes the blast. | B. 290 characters; tricolon of advice; tactics lecture. | A huge biter that bursts at the nearest turret, damaging all turrets nearby. |
| lp-bred-scout | It circles a defence before a wave comes: the warning. Kill it and the next scout there loops wider; the wave comes all the same. | A. "the warning"; explains AI; C. defence. | Circles your defenses before an attack. |
| lp-bred-carrier | A mature culture's seed, walking with an escort to a wild nest field where a new culture will begin. Kill it on the way and the culture has paid for nothing. | A. "has paid for nothing". | Carries a new Synthexis culture to wild spawners. |
| lp-harrier | Grubstake's flier: scrap and a gun, weak and cheap, sent in numbers over your walls. | B. List construction. | A cheap flying drone that attacks in numbers. |
| lp-scavenger | Grubstake's flier with a charge in it: it flies at your artillery, mortars and radars and blows up on them. Shoot it down before it arrives. | B. Advice. | A flying bomb that targets artillery, mortars and radars. |
| lp-laser-drone | Kessler-Hayashi's flier: armoured and few, with a laser beam. Small arms barely scratch it; flak and rockets bring it down. | B. Counter-advice; C. spelling. | An armored flying drone with a laser. Resists bullets. |
| lp-skyguard | Kessler-Hayashi's answer to fliers: a long laser that tracks what flies, and a weak shot at the ground. | A. "X's answer to fliers" repeated across three units. | Long-range laser against flying units. Weak against ground targets. |
| lp-flak-buggy | Grubstake's answer to fliers: scrap flak bursting in the air, and a weak splash on the ground. | A. Same template. | Fires flak at flying units. Weak against ground targets. |
| lp-bred-spore | Synthexis's answer to fliers: spit that bursts into spores where it lands, aloft as well. Weak against the ground. | A. Same template; "aloft as well". | Spits spores that hit flying units. Weak against ground targets. |
| lp-bred-stomper | A bred pentapod that steps over your wall and stomps what stands inside. Rockets, slugs, heavy tanks, fliers and artillery bring it down; rifles barely do. | B. Five-item counter list. | A bred pentapod that steps over walls. Resists bullets. |
| lp-biochamber | Where Synthexis feeds an incubator. While it works, the incubator breeds. | C. "Where…" fragment. | Feeds a Synthexis incubator so it can breed. |
| lp-clinic | Where Synthexis improves its breeds. While it stands they grow stronger; destroyed, its incubators breed only small and medium biters until a new one lands. | B. Inverted clauses. | Makes Synthexis biters stronger. Without it, only small and medium biters are bred. |
| lp-runt | Thrown at your wall to see which turrets fire. Where one stays silent, the herd comes in. | A. "the herd comes in". | Tests your defenses for gaps before an attack. |
| lp-sweeper | Sent into your minefields ahead of a siege. It bursts among the mines and clears a lane for the herd. | B. Narrative. | Bursts in minefields to clear a path before an attack. |
| lp-tumor | Grows Synthexis's creep round it. Nothing can be built on creep. | C. "round". | Spreads Synthexis creep around it. Nothing can be built on creep. |
| lp-bred | Bred by Synthexis in an incubator and marked in its colours. The wild biters leave it alone, and it leaves them alone. | B. Chiasmus; C. colours. | Bred by Synthexis. Wild biters do not attack it. |
| lp-skim-yard | Where Grubstake keeps what it skimmed. Destroyed, what it holds spills. | B. Inverted syntax; "skimmed". | Stores what Grubstake has stolen. Drops its contents when destroyed. |
| lp-invoice-post | Kessler-Hayashi bills you here for the biter waves your pollution sends through its ground. Pay in circuits, modules, steel and the like, by their worth (other items stay). Paid off, it buys a truce: no attacks, and its line holds, for a minute per 10 paid (10 to 60). | B. 270 characters; three parentheticals. | Bills you for attacks your pollution causes. Paying in full buys a truce of 1 minute per 10 value. |
| lp-muster-point | Trooper, breacher and tank orders put in it become units here, sent to the nearest rally beacon. A barracks wired with signal P keeps its orders as items for you to carry here: by train, belt or robot. | B. Second sentence is a tutorial; tricolon. | Turns unit orders into units and sends them to the nearest rally beacon. |
| lp-threat-scanner | Counts the corporations' units within 64 tiles, by kind, each second: a signal for each kind, a total for each corporation, the building crews apart, and the biters. Wire it to deciders and a rally beacon. | B. Long list; instruction. | Outputs the number of enemy units within 64 tiles, by type. |
| lp-jammer | Downs construction and logistic robots in its arcs, so what its siege breaks stays broken. Destroy the mast, or keep your roboports out of its reach. | B. Explains purpose; advice. | Destroys construction and logistic robots in range. |
| lp-claim-stake | Mineral rights reassigned, driven out by a Grubstake truck. Unworked ground is claimed when the lamp runs out (it turns red near the end). Drill or stake the patch, or pull this down, and the claim is off. | A. Euphemism; B. long. | Grubstake claims this ore when the lamp runs out. Mine the ore or destroy the stake to stop it. |

### 2.4 Technology descriptions

All six faction technologies end with "Research by disassembling …". The game already shows the research trigger
("Craft …") in the tooltip; vanilla trigger technologies never repeat it.

| Key | Current | Problem | Proposed |
|---|---|---|---|
| lp-pact-breaker | Grubstake's pacifier crystal, taken apart: set inside a Grubstake claim, it jams its pact with the biters for 3 minutes. Research by disassembling a pacifier crystal. | B. Lead-in and trigger repeated. | Jams Grubstake's pact with the biters for 3 minutes. Must be placed in a Grubstake claim. |
| lp-claim-marker | Grubstake's pacifier crystal, taken apart: Grubstake reads your buildings within 40 tiles of the marker as its own claim and leaves them alone. Research by disassembling two pacifier crystals. | B. Same. | Grubstake leaves your buildings within 40 tiles of the marker alone. |
| lp-orbital-strike | Kessler-Hayashi's orbital beacon, taken apart: a beacon that, charged on your power, calls Kessler-Hayashi's own barrage on every nest and enemy building within 60 tiles, and burns out. Research by disassembling an orbital beacon, from a Kessler-Hayashi lander or uplink. | B. 270 characters, nested clauses. | A single-use beacon that calls an orbital barrage on enemies within 60 tiles. |
| lp-rail-rifle | Kessler-Hayashi's railgun, taken apart: a rifle whose slug pierces a 30-tile line. Research by disassembling two rail coils, from Kessler-Hayashi's railgunners. | B. Same. | A rifle whose slugs pierce everything in a 30-tile line. |
| lp-pheromone-bait | Grubstake's gland, taken apart: a bait that calls the idle biters round it to attack whatever they meet there. Grubstake's pact keeps them off Grubstake. Research by disassembling three pheromone glands, from Grubstake's pacifier antennas and Synthexis incubators. | B. 280 characters. | Bait that makes nearby biters attack whatever is around it. |
| lp-cluster-shells | Kessler-Hayashi's cluster fuze, taken apart: your artillery shells burst into bomblets round the impact. Research by disassembling three cluster fuzes, taken from Kessler-Hayashi's mortars and howitzers. | B. Same. | Artillery shells that scatter bomblets on impact. |
| lp-command-bandwidth | More command relays carry your units. The first level unlocks barracks and grants a command core; more come from the Landing Party's wreckage. | B. "Landing Party" is the mod name, not an in-game party. | Increases the number of command relays that control your units. |

### 2.5 Mod settings, signals, item description

| Key | Current | Problem | Proposed |
|---|---|---|---|
| mod-description.landing-party | A rival machine faction lands and builds a factory of its own. Prototype. | C. There are three factions. | Rival factions land and build factories of their own. |
| mod-setting-description.lp-grubstake-strength | How much army Grubstake fields: its camps' unit cap. | B. "How much army". | Maximum units per Grubstake base. |
| mod-setting-description.lp-serenity-strength | How much army Kessler-Hayashi fields: its camps' unit cap. | B. Same. | Maximum units per Kessler-Hayashi base. |
| mod-setting-description.lp-biotech-strength | How much Synthexis breeds: the biomass it earns (from the pollution its creep drinks, its incubators' trickle and its pod). | B. Internal economy explained. | How fast Synthexis breeds biters. |
| mod-setting-description.lp-grubstake-aggression | How soon Grubstake acts: its ladder's climb, the gaps between its operations, answers and heists, and how long it keeps trying before standing down. | B. Internal terms (ladder, answers, heists). | How soon and how often Grubstake attacks. |
| mod-setting-description.lp-serenity-aggression | (same text for Kessler-Hayashi) | B. Same. | How soon and how often Kessler-Hayashi attacks. |
| mod-setting-description.lp-biotech-aggression | How soon Synthexis attacks: the gap between its waves, and its first after landing. | C. Colon construction. | Time before Synthexis's first attack and between attacks. |
| mod-setting-description.lp-chat-notices | Tell the corporations' moves in chat and with alerts (for debugging). Off, they show in the world only; a corporation's first landing and a lost settlement are always told. | B. Inverted syntax; "(for debugging)" contradicts a player setting. | Show faction activity in chat and as alerts. First landings and destroyed bases are always shown. |
| virtual-signal-name.lp-scan-hauler | Corporation haulers (a siege or a strip camp) | B. Parenthetical in a name. | Corporation haulers |
| virtual-signal-name.lp-scan-jammed | Scanner jammed (a corporation's jammer mast in reach; it reads nothing else) | B. Explanation in a name; "jammer mast" vs entity "jamming mast". | Scanner jammed |
| item-description.lp-command-tool | Drag over your units to select them; shift-drag releases them to their beacons.\nRight-click or right-drag: move there, or attack a faction building.\nShift-right-click: attack-move. | C. Hard-coded keys; vanilla uses control tokens. | Select units to command them.\n\_\_CONTROL_RIGHT_CLICK\_\_ to move or attack. |

### 2.6 Literal English in Lua (unlocalised)

| Where | Current | Problem | Proposed (as a locale key) |
|---|---|---|---|
| `scripts/map.lua` label(), `standing.get` | rival / enemy / truce | C. Unlocalised; lowercase on the map. | Rival / Enemy / Truce |
| `scripts/map.lua:46` | fallen | C. Unlocalised; "fallen". | Destroyed |
| `scripts/base.lua:643` (chart tag) | \<name\> (fallen) | C. Same. | \<name\> (destroyed) |
| `scripts/faction.lua:742` CAP_NOTICE | harriers | C. The unit is named "Scrap drone". | scrap drones |
| same | pickets that report what they see | B. Explains the AI. | scouts |
| same | siege operations | A. Corporate. | sieges |
| `scripts/prospect.lua:116` chart tag | Mineral rights reassigned | A. Euphemism. | Grubstake claim |
| `shared.lua` mottos, shown by `lp.landed` | Resources in the right hands. / Please remain behind the line. | A. Slogans. | Drop from notices (see `landed`). |
| `look.lua:20` tile names | Grubstake Inc. road / pad / trim / stripe / apron / hazard | C. Built by concatenation, lowercase, unlocalised. | Locale keys: "Grubstake road" etc. |
| `scripts/siege.lua` | Packing up / Deploying / Packing up N% / Deploying N% | Wording fine; unlocalised. | Keep wording; move to locale. |
| `scripts/farm.lua:254`, `scripts/phases.lua:132` | Synthexis culture N / Survey party | Wording fine; unlocalised. | Keep wording; move to locale. |

## 3. Strings that are fine

**Locale: 220 of 331 fine** (111 flagged, including the two dead keys). By section: entity names 89 of 93, item names
33 of 38, recipe names 6 of 6, technology names 9 of 9, mod-setting names 7 of 7, string-mod-setting 30 of 30,
virtual-signal names 10 of 12, damage types 3 of 3, tile, shortcut, controls, mod-name 4 of 4, `[lp]` messages 29 of
89, entity descriptions 0 of 24, technology descriptions 0 of 7, mod-setting descriptions 0 of 7, item description 0
of 1, mod description 0 of 1.

Fine messages include: `clearing`, `withdrawing-*`, `alert-raid`, `alert-strip`, `alert-loot`, `pact-broken`,
`pact-restored`, `strike`, `breaker-lit`, `breaker-outside`, `rig-down`, `alert-rig`, `prospect-claimed`,
`standing-enemy`, `standing-rival`, `invoice-truce`, `tribute`, `crew-gave-up`, `border-broken`, `tap-cut`,
`relief-drop`, `node-lance`, `node-shock`, `node-prism`, `plate-fire`, `plate-laser`, `command-dev`, `command-trace`.

**Lua literals: 8 of 20 fine in wording** (Packing up, Deploying and their percentages, Synthexis culture, Survey
party, and the level-up items "walkers" and "a headquarters"), though all 20 are unlocalised.

## 4. Missing descriptions

Vanilla gives a description to every building and item the player crafts or places, and to enemy structures with a
special role (demolisher, captive spawner). In 2.x an item with no description shows its place result's description,
so the entity line covers both.

Player buildings and items with none:
- **Barracks**: "Trains units from orders. Needs a command core." (vanilla equivalent: assembling machine)
- **Rally beacon**: "Gathers units and gives them orders by signal."
- **Command relay**: "Lets you control 10 more units. Requires power."
- **Command core**: "Needed to build a barracks. Dropped by destroyed corporation buildings."
- **Border stake**: "Place toward a Kessler-Hayashi base to set a border."
- **Trade post**: "Grubstake collects items placed here in exchange for a truce."
- **Pact breaker**, **Claim marker**, **Orbital strike beacon**: the technology text, shortened (2.4), as entity
  descriptions.
- **Mortar** (player): "Short-range artillery that fires mortar shells." (vanilla: artillery turret)
- **Strip drill**: "Mines the ore around it quickly, then exhausts." (check the mechanic)
- **Pheromone bait** (entity and item): "Makes nearby biters attack whatever is around it."
- **Rail rifle**, **Rail slug**, **Cluster artillery shell**, **Mortar shell** (vanilla gives every weapon and ammo
  a tooltip through its stats; a one-line description is optional, but the rail rifle's piercing is not visible in
  stats).
- **Unit orders** (5): "Turned into a unit at a barracks or muster point." One shared string.
- **Salvage drops**: pheromone gland, pacifier crystal, rail coil, cluster fuze, orbital beacon, drill head, and the
  five disassembled items. Vanilla's nearest equivalents (crash-site items, Gleba spoilage) carry a line. Suggested:
  "Salvaged from \<faction\>. Can be researched." on the drops.

Enemy structures with a role the player must know and no description:
- **Pacifier antenna**: "Keeps biters from attacking Grubstake. Drops a pacifier crystal."
- **Claim jumper rig**: "Digs a tunnel to your base. Destroy it before it breaks through."
- **Power tap** / **Power tap receiver**: "Draws power from your electric network."
- **Headquarters uplink**: "Destroying it stops further landings."
- **Lander**: "The center of a corporation base."

Technologies: `lp-prize-serenity` and `lp-prize-grubstake` have no description (hidden technologies, seen only in
the "research completed" notice; low priority).

## 5. Inconsistent naming

| Thing | Names used | Recommendation |
|---|---|---|
| Biter spawner | nest, nests, nest field, wild nests (vanilla: spawner, enemy base) | spawner |
| A corporation location | settlement, camp, base, outpost, site, perimeter site, claim, regional office, holdings | base for the whole; outpost and claim only where they are distinct objects |
| The rivals collectively | corporation, faction, Landing Party, "whoever sent it", "its owners" | faction in player text (signals say "Corporation") |
| Grubstake | Grubstake Inc. (chat via `corp_label`, `hq-down`, `withdrawing`, tile names), Grubstake (entities, settings, techs) | Grubstake |
| Reinforcements | contractors, relief detachment, reinforcements | reinforcements |
| Headquarters | regional headquarters, regional office, headquarters, Headquarters uplink, uplink, Head Office | headquarters; uplink for the entity |
| Scrap drone | Scrap drone (entity), harriers (level-up notice), flier | scrap drone |
| Jamming mast | jamming mast (entity, node), jammer mast (signal) | jamming mast |
| Flying units | flier, fliers, aircraft (signal), "what flies" | flying units; signal "Corporation flying units" |
| Building crews | crews, drones (`line-held`), building crews (signal) | building crews |
| Mortar | "Mortar" is both the player's and the corporations' entity (the corp copy gets a suffix) | acceptable; consider "Siege mortar" for the corporation's |
| Orbital beacon | Orbital beacon (salvage item), Orbital strike beacon (crafted) | Orbital beacon parts / Orbital strike beacon |
| Landing vehicle | lander, craft (`signs`), pod (Synthexis, `biotech-strength`) | lander; pod for Synthexis only |
| "range" | in reach, within reach, in its arcs (vanilla: in range) | in range |
| Spelling | armour, armoury, defence, colours, round (vanilla: armor, defense, color, around) | US spelling |
| Time | ten minutes, five minutes, two and a half minutes, 3 minutes (vanilla: digits) | digits |
| Placeholders | `hq-down-*`, `withdrawing-*`, `border-none` type the corporation name; all others use \_\_1\_\_ with `corp_label` (icon and name) | one key each with \_\_1\_\_ |
