# The manual's voice and pictures: a consult against the 1990s manuals (Fable, 2026-11-05)

Brief: the user, on the manual's first full draft: "Can you look at lore blurbs and manual layout from real game
manuals from back then? Yours reads quite inauthentic but I can't put my finger on what's wrong. A mix of uncanny
valley / AI slop maybe. Also some screenshots are reused a lot it seems? And not extra clear." The manual's brief: an
old-school RTS manual, a nice object, a field guide in the manner of StarCraft's 1998 manual, A5, lore by a narrator in
third person. Lore direction: not centred on Nauvis; Kessler-Hayashi lives in orbit (a security contractor, fleets and
contracts across the system); Synthexis has interests on Gleba (a link, not a home); Grubstake has no home world.

Read: `docs/manual/*.qmd`, `docs/manual/words.cfg`, `docs/manual/_generated/`, the rendered PDF (88 pages, all looked
at as contact sheets, twelve pages at 90 dpi), the template (`_extensions/lp-manual/`), DESIGN.md's Kessler-Hayashi
rows, `docs/corporations-brief.md`. Sources: the manuals themselves, as scans and OCR text (section 1 lists where each
came from). Read-only on the repo except for this file.

The short version. The 1990s manuals are **loud, specific and partisan**. They name people, give dates and sums,
number their files, pick a narrator with an interest, and relish it. Ours is **quiet, general and even**: a narrator
who knows everything and names nothing, paragraphs that each close on an aphorism, sentences of one shape, and the
design document's vocabulary in the lore's mouth. That evenness is what reads as machine-written. The pictures have the
same problem from the other side: one zoom, one angle, one light, and three of the eight vistas used twice.

---

## 1. What the real manuals did

Where each quote comes from: Command & Conquer (Westwood, 1995; the 1998 Windows 95 OEM manual,
`cnc-comm.com/files/CC-Manual.pdf`, text extracted with pdftotext); Red Alert (Westwood, 1996; archive.org item
`ccredalertreferencecards`, OCR); StarCraft (Blizzard, 1998, UK printing; archive.org item `manual_Starcraft`);
Warcraft II (Blizzard, 1995; the Battle.net Edition manual, archive.org item `warcraft-2-battlenet-edition`, same lore
text as 1995, and `warcraft.wiki.gg/wiki/Warcraft_II_manual`); Homeworld (Relic/Sierra, 1999; archive.org item
`Homeworld_Manual`, the gameplay guide; the Historical and Technical Briefing was a separate booklet I could not get as
text, so what I say of it comes from the fan lexicon excerpts the search returned and is marked as such); Dark Reign:
Rise of the Shadowhand (Activision, 1998; archive.org item `dark-reign-expansion-manual`); Age of Empires (Ensemble,
1997; archive.org item `manual_Age_of_Empires`); Total Annihilation (Cavedog, 1997; the jewel-case manual on archive.org
has no lore; the story text is from the online user's guide mirrored at discmaster.textfiles.com). Alpha Centauri's
manual I could not get as text; Myth's and Dune 2000's neither. Nothing below is from memory.

### 1.1 Two families: the dossier and the chronicle

**The briefing family (Westwood: C&C, Red Alert).** The lore is an *intelligence file*, in capitals, with fields. C&C's
page 2, in full form:

> THE BROTHERHOOD OF NOD. Commonly, The Brotherhood, The Ways of Nod, Sha'Seer among the tribes of Godan; see INTERPOL
> File ARK936, Aliases of the Brotherhood, for more.
> FOUNDED: Date unknown: exaggerated reports place the Brotherhood's founding before 1,800 BC
> IDEOLOGY: To unite third-world nations under a pseudo-religious political platform with imperialist tendencies. In
> actuality it is an aggressive and popular neo-fascist, anti-West movement vying for total domination of the world's
> peoples and resources. Operates under the popular mantra, "Brotherhood, unity, peace".
> CURRENT HEAD OF STATE: Kane; also known as Caine, Jacob (INTERPOL, File TRX11-12Q); al-Quayym, Amir (MI6 DR-416.52)
> BASE OF OPERATIONS: Global. Command posts previously identified at Kuantan, Malaysia; somewhere in Ar-Rub' al-Khali,
> Saudi Arabia; Tokyo; Caen, France.
> ECONOMIC STRENGTH: Considerable operating assets believed to be in excess of US$255.2 billion, based on audits of
> seized financial records (see CIA Docket 3231.54-776 FIA).
> SEE ALSO: Mobius, Dr. R.H.; terrorist activities; United States Global Defense Act; Report of World Energy Radical
> Redistribution, US Congressional Report, 1994, File XXY22.

And GDI, the same form: "FOUNDED: 12 October 1995, in accordance with the United Nations Global Defense Act (UNGDA)",
"MILITARY STRENGTH: Within parameters of the UNGDA, Article V, Section 3A, Paragraph 12." Red Alert repeats the form
for the Soviets: "CURRENT HEAD OF STATE: Josef Stalin", "Command posts identified in Moscow, Kiev, Stalingrad, Khartoum,
Karachi, Da Nang", "Enlisted forces exceed 14 million", "operating assets believed to be in excess of 486.2 billion
Swiss Francs". The title page carries one quote with a file reference: "'We have waited centuries for this moment. The
rivers will flow with the blood of those who oppose us.' -- Kane, suspected leader of the Brotherhood of Nod (Global Net
Interpol, file #GEN4:16)".

What to take from it: the facts are **fake-precise** (US$255.2 billion, 52%, 12 October 1995, File TRX11-12Q) and the
voice has an **interest** (it is Interpol's file, and it is scared). Every line is a proper noun or a number. There is
no mood writing at all; the mood comes from the dryness of the form against the content.

**The chronicle family (Blizzard: StarCraft, Warcraft II).** StarCraft's history is twenty pages of third-person
narrative, in two columns, dense with names, dates, numbers and verdicts:

> By the end of the twentieth century, there were six billion people upon the earth. Within three hundred years, the
> population had grown to an estimated twenty-three billion.

> Tarsonis, the largest and most technologically advanced of the colonies, soon developed second generation sub-warp
> engines. [...] Thus the Kel-Morian Combine was formed; a shady, corporate partnership that would supply military aid
> to any Mining Guild that was oppressed by Confederate policy. [...] The Guild Wars lasted for nearly four years, with
> the Confederacy eventually "negotiating" peace with the Combine.

> The Confederates sent three of their deadliest assassins, known only as Ghosts, to eliminate Mengsk and his
> supporters on Korhal. The Senator's decapitated body, along with those of his wife and young daughter, were found
> the next morning on the private balcony of his towering, fortress-like headquarters. Mengsk's head was never found.

> A salvo of one thousand Apocalypse-class nuclear missiles was fired at the planet of Korhal from the distant
> Confederate capital of Tarsonis. Over 4,000,000 people were annihilated during the savage attack. In a single
> instant, the prosperous colony of Korhal was reduced to nothing more than a super-heated sphere of blackened glass
> and stirring phantoms.

Note what the narrator does: he takes sides in adjectives ("shady", "clumsy", "despicable", "pampered", "ragtag",
"savage") and he over-writes ("stirring phantoms"). Sentences run long, with subordinate clauses, and they do not land
on epigrams; they land on the next fact. The species overview that follows is the game's mechanics explained from
inside the world: "The key to the survival of the Terran species is flexibility. Their primary structures are equipped
with self-contained thruster systems that enable low altitude flight."

Warcraft II goes one step further and gives the chronicle a **named first-person narrator with a stake**. The human
history is "A history of the fall of Azeroth", told by Aegwyn: "My name is Aegwyn, and for over one thousand years I
have wandered the realms of this world [...] I gave birth to a son and named him Medivh - or 'Keeper of Secrets' in
the ancient tongue of the Elves - in the fall of the year 559." The orc history is "The History of Orcish Ascension (as
told by Gul'dan, Chieftain of the Stormreaver clan)": "Like an elemental force of havoc and destruction we thundered
through the lands of the Draenei devastating all that we beheld. Not one life was spared. No building was left
standing. [...] The Draenei were a weak people - hardly worth the effort of our raiding sweep." Before the histories
come "Legends of the Land", a page of profiles (Lothar "has spent well-nigh all of his fifty-seven years in service to
the lands he calls home"), and "Creatures, resources and places of mystery" (the Runestone, the Tomb of Sargeras, the
Portal "some fifty feet above the marshy ground of the Black Morass").

**The in-universe document (Dark Reign, Homeworld).** Dark Reign's expansion opens its lore as a transmission:
"TRANSMISSION // [...] Colonel Cassio Bovarr, Kinshasa, Earth [...] Dr. Horus Baraadanov", then a letter: "Welcome,
Colonel. I wish we could greet you under better circumstances. Be assured we are all saddened by the news of your
friend Colonel Farahn's unfortunate accident, but of course you know as well as anyone the unpredictable nature of our
universe." It names a project ("Project Kraken"), a date ("initiated more than eight years ago"), a place ("the
Imperium Military Archives on Mars"), a serial ("One such personality, designated D8312"). Homeworld's briefing booklet
(from the lexicon excerpts; not verified against the scan) is written as a Kushan historical summary with its own
calendar, named clans (kiithid), a named site (Khar-Toba), a dated find ("has been dated at more than 3,000 years old")
and a relic with an inscription (the Guidestone).

**The encyclopaedia (Age of Empires).** Each civilisation gets "Location", "Rise to power", "Economy", "Decline and
fall", in a neutral third person that is nevertheless all dates and names: "Babylonia was founded as a kingdom around
1900 BC by Semitic Amorite barbarians [...] In 1792 BC the small kingdom was inherited by Hammurabi who ruled until
1750. During those 42 years, Hammurabi extended the kingdom to encompass all of Sumer to the east and Akkad to the
north." This is the one period model for a *detached* narrator, and it works because it is dense: a date or a name in
every sentence.

**The pulp epigram (Total Annihilation).** TA does end on epigrams: "For each side, the only acceptable outcome was the
total annihilation of the other." But before it comes the specific: "After four thousand years of fighting, both sides
came to stalemate", a named process ("patterning"), and a clear mechanic in the lore ("on the whole CORE units are
slightly more heavily armoured, but slower than their ARM counterparts"). One epigram per page, and it is the title.

### 1.2 How units are introduced

**StarCraft** (the bestiary the user asked for). Each unit: name, a two-line header, a background paragraph, then
abilities as indented sub-entries with their own icon:

> Marine
> Role: Armoured Infantry Trooper
> Armament: CMC-300/400 Powered Combat Suit; 8mm C-14 "Impaler" Gauss Rifle
> Marines are the first line of defense for most Terran colonies. A majority of them were at one time criminals or
> rebels who have undergone mandatory Neural Resocialisation. Freed from any previous allegiances or ideologies, these
> fearless men and women are ready to defend Confederate interests with their lives.
> The Powered Combat Suit worn by Confederate Marines is effective against most small-arms fire [...] The C-14 Impaler
> Gauss Rifle fires 8mm metal "spikes" at hypersonic speeds. [...] To preserve both ammo usage and minimise power
> requirements, the rifle uses a capacitor system to fire in short, controlled bursts.

> StimPack [...] Side effects including insomnia, weight loss, tremors, grand mal seizures, mania/hypomania, paranoiac
> hallucinations, severe internal hemorrhaging and cerebral deterioration have all been declared nominal and well
> within Confederate acceptable safety margins.

> Zergling. Type: Light Assault Warrior. Core Genus: Zz'gashi Dune-runners. Primary Attack: Claws. The small, savage
> dune-runners of the sand-world Zz'gash were incorporated into the Zerg Swarm to serve as scouts and initial assault
> troops. [...] Because the genetic code of the Zergling is so simple to replicate, a single Larva can spawn two
> separate Zerglings.

> Dragoon. Veteran Protoss warriors who have been crippled or mortally wounded in combat can volunteer to continue
> their service to the Conclave by being transplanted into Dragoon exoskeletons.

The pattern: **the unit is a thing with a maker, a model and a provenance**; the mechanic is stated as a property of the
hardware or the biology ("a single Larva can spawn two"), never as a rule; the humour is deadpan and comes from the
institution's voice (the StimPack's safety margins). No stat bars at all in the 1998 manual: the numbers were in the
game. There is also no "counters / countered by" line; the tactical advice is a sentence inside the paragraph ("Care
should be taken when scouting for resources in Zerg inhabited areas, as any number of Zerglings could be lying in
wait").

**C&C / Red Alert.** Name in capitals, a stat block in capitals (ARMOR, COST, SECONDS TO PRODUCE, RANGE, WEAPON), a
greyscale render, a paragraph of hardware plus advice in the second person:

> MAMMOTH TANK. ARMOR: HEAVY. COST: 1500. SECONDS TO PRODUCE: 80. RANGE: MED/LONG. WEAPON: DUAL 120MM APDS / MAMMOTH
> TUSK MISSILES. Armed with dual 120mm cannons and Mammoth Tusk Missiles, this giant is a very versatile attack unit.
> These weapons help compensate for its lack of speed and mobility. When this unit takes a lot of damage, it can
> slowly regenerate its health back up to 50%.

> STEALTH TANK. This lightly-armored tank is equipped with the Lazarus shield, cloaking it from enemy sight. This
> shield is neutralized during firing, giving the tanks the ability to "appear" out of thin air.

> OBELISK OF LIGHT. [...] Make sure you have excess power before building these, because damage to your power plants
> will keep the obelisks off-line.

**Warcraft II.** Name, a painted portrait, one paragraph of pure character, no numbers:

> Grunt. Those Orcs who distinguish themselves enough in the arts of war to be trained as Grunts epitomize the
> merciless spirit of the Horde. Equipped with mighty axes and battle-worn armor, they are prepared to fight to the
> death. Devoted to the Horde and to their clans, the Grunt lusts for battle - wanting nothing more than to wade into
> the field of carnage and die a bloody death surrounded by the bodies of his fallen enemies.

> Ogre. Due to the constant bickering between their two heads, Ogres exhibit less intelligence than even the lowly
> Peons.

**Homeworld.** A stat grid per ship (armor, coverage, maneuverability, max. velocity, special function, Kushan and
Taiidan columns), a wireframe drawing, and one paragraph of the commander's reasoning: "While less maneuverable than
the Scout, the Interceptor easily compensates with its much heavier weaponry. The Interceptor is a good Fighter killer
and stacks up favorably against Capital Ships when used in greater numbers."

### 1.3 Page layout

- **Page types** in all of them: a title page with one quote; the dossier or chronicle (text-heavy, two columns,
  framed by art, no screenshots); an interface chapter with **one screenshot per screen and callouts**, thin leader
  lines from a label to the element (Homeworld's options page does this; C&C's "Sidebar", "Radar" walkthrough; Age of
  Empires' game screen with numbered labels); the unit chapter (one unit per block, art, stats, paragraph); tables at
  the back (C&C's "Hierarchy" tables: unit, cost, speed, armor, prerequisite, weapon).
- **Art, not screenshots, for units.** StarCraft: a small rendered sprite in a hex frame, plus the painted portrait of
  the face for the heroes; C&C: a greyscale 3D render of each unit on white; Homeworld: line drawings; Warcraft II:
  painted portraits. Screenshots appear only to teach the interface, and then annotated.
- **Typography.** Display faces with attitude (StarCraft's stencil-on-steel frame; C&C's Futura Bold and Russell Square
  capitals; Homeworld's thin small caps on a grid); body text in a plain serif or sans, often justified, two columns in
  the history chapters. Section heads are large and in the world's own voice ("UNDERSTAND YOUR ENEMY", "The Great
  Purification", "Legends of the Land").
- **Frames and furniture.** StarCraft's every page sits in a metal frame with a race-specific texture; Homeworld's pages
  carry the kiith sigil and a page number in a rail; C&C's run a chapter tab down the outer edge in capitals. The page
  is dressed as an object of its world, not as a document about the world.

---

## 2. Diagnosis of our text

The manual's **mechanics prose** (sieges, the line, the invoice post, the circuit control) is good: concrete, in the
second person, each sentence carrying a fact a player can use. The 90s manuals' walkthrough chapters are not better
than it. The problem is confined to three places: the lore pages, the unit blurbs and roles, and the openers' and
chapter leads' one-line summaries. These are where the reader expects a *voice* and gets a *style*.

### 2.1 The lore pages

**Every paragraph closes on an epigram.** Count the last sentence of each paragraph of the four lore pages:

- "A factory that has paid for its own beginnings is the cheapest thing in the system to take over."
- "Nauvis was never in those books."
- "Surface activity confirmed. Reclassify as commercial."
- "The contract starts with the first rocket. A world that launches has traffic, and traffic is what Kessler-Hayashi
  sells."
- "If the uplink falls, the company writes Nauvis off."
- "A claim is worked until it pays no more. Then the crews fold the camp and the landers lift for the next one."
- "Everything here is claimed, or about to be."
- "It will leave Nauvis the way it left everywhere else, with the ore gone and the yard full."
- "To a bioengineer that is a laboratory that runs itself, with the engineer supplying the pressure free of charge."
- "The wall held, and the next wave came for the wall."

Ten paragraph endings, ten aphorisms. Each one is good on its own; in a row they are a tic, and the tic is the single
strongest machine tell in the book. In StarCraft's twenty pages of history I found one sentence of this shape ("Mengsk's
head was never found"), and it is a fact, not a moral. TA has one per page and it is the page's title.

**Balanced, chiastic cadences.** "traffic is what Kessler-Hayashi sells"; "A world that launches has traffic";
"Gleba grows back faster than it can be harvested, and Aquilo is ice"; "grown fast and spoiling faster"; "The wall
held, and the next wave came for the wall"; "with the ore gone and the yard full"; "a link, not a home" (from the
brief, and the lore reproduces its shape). These are the same two-beat seesaw each time. A period writer varies; the
seesaw is a signature.

**Abstraction with no named specifics.** "The company does not say who signed it." "Where Synthexis began, the company
does not say." "Its offices ride a ring of armed platforms." "a foundry company on Vulcanus went under" (which one?).
"One engineer had already wired a planet" (the engineer is the only person in the book, and has no name because the
game gives none; fine, but then everyone else needs one). There is not one personal name, one ship's name, one
station's name, one contract number, one date, one sum of money in four pages of lore. The 90s manuals are the
opposite: in the one C&C page quoted above I count eleven proper nouns and six numbers. The manual *has* numbers, 300
of them, but they are all in the mechanics; the lore is the one place that has none, which inverts the period
convention exactly (StarCraft's history has numbers; its unit pages do not).

**An omniscient detachment no 90s writer had.** Our narrator sees from orbit and from inside the company's filings
and from the biters' spawners, and has no opinion on any of it. "In the company's filings the engineer appears as a
hazard on a contracted site" is the closest the book comes to an attitude, and it is reported, not felt. Blizzard's
narrator calls the Confederacy "often-corrupt" and its Senators "pampered"; Westwood's file-writer is frightened of
Nod; Gul'dan despises the Draenei and says so. A narrator with no stake is what a model produces when asked for
"third person". The brief said third person; it did not say nobody.

**Design-document vocabulary.** "the pressure grows with you" (index), "planned waves", "it changes after every attack
that fails", "a laboratory that runs itself, with the engineer supplying the pressure", "it reads 'left behind'
generously", "the swarm is worth having". *Pressure*, *planned*, *reads*, *worth having* are DESIGN.md's words for
tuning knobs. Inside lore they sound like a designer explaining a system, because they are.

**Mechanics in lore, stated as rules.** "Its research happens in labs on the ground, one to each branch of the work,
and a branch stops when its lab is gone." "Biters that wander from the engineer's smoke into its camps are billed at an
invoice post, and a paid invoice buys a quiet spell." These are the mechanics chapter's sentences with the numbers
removed. StarCraft does put mechanics in lore, but as hardware ("the rifle uses a capacitor system to fire in short,
controlled bursts"), and the Westwood files put them as facts about an organisation ("supports significant land, sea,
and air military operations").

**One sentence shape.** Subject, verb, object, "and", subject, verb, object. "Walls go up before the camp is finished,
and a dome stands over it against artillery." "Its trucks go out after dark, and its raiders take a machine apart where
it stands and carry the parts home in the morning." "Creep spreads from the tumors and drinks the pollution from the
air." Two independent clauses joined by "and", present tense, no subordination, in nearly every sentence of all four
pages. StarCraft's sentences are front-loaded with participial and subordinate clauses ("Having lost the means to
communicate over interplanetary distances when their ships were stripped for essential materials, the Terrans lived in
isolation for decades"). The 90s sentence is baggier, and the bagginess is the humanity.

**Pull quotes that are aphorisms by an unnamed source.** "Freight register, Nauvis orbit"; "Kessler-Hayashi site
report"; "Grubstake prospector's log"; "A survivor's log". C&C's quote is Kane's, with a file number; Dark Reign's letter
is from Dr. Horus Baraadanov to Colonel Cassio Bovarr. An unnamed source is the same evasion as "the company does not
say".

### 2.2 The unit blurbs and roles (`words.cfg`)

**One template, eight times.** "Fielded once your infantry has cost Kessler-Hayashi enough." "Fielded against fliers
and combat robots." "Fielded against turret lines." "fielded when your vehicles have been killing its units." "Grubstake
buys them once your vehicles have killed enough of its raiders." "Grubstake fields sappers once your infantry has cost
it enough." "Grubstake buys it once your fliers and combat robots have cost it enough." "Grubstake buys it against
turret lines." That is the research trigger, which the tree page already states, restated in the card's one free
sentence. It makes the blurbs read as a table in prose, which is the list-like rhythm the user sensed.

**The blurb describes the AI, not the unit.** "A wall that has stopped Grubstake's raids often enough meets a dozer."
"Bred for walls that have held." "Sent one rank at a time at the turrets covering a wave's way in." These say when the
planner spends the unit. A period blurb says what the unit *is* (its maker, its kit, its temperament) and lets the
reader infer when it comes. Compare "Laser drone: Kessler-Hayashi's sky. Laser drones come from the company's second
level, a few at a time, and fly over walls. Bullets barely scratch them." with Westwood's "This lightly-armored tank is
equipped with the Lazarus shield, cloaking it from enemy sight. This shield is neutralized during firing". The second
gives the hardware a name and a weakness in the same breath; the first gives a schedule.

**Two-word fragments as openers.** "Kessler-Hayashi's sky." "Scrap and a gun." "Fast, light and everywhere."
"Cheap, quick to train and quick to lose." Three of these are tricolons; all four are the fragment-then-explanation move
that reads as copywriting. No period blurb opens on a fragment; they open on a full sentence with the unit as subject.

**The role lines in `words.cfg` are fine where they describe** ("Walks between the biochambers and keeps them running")
and tic-ridden where they summarise ("Bred, tinted and sent with a plan"; "The body of a grown wave").

**The counters are the one period-authentic thing on the card**, but C&C and StarCraft did not have them; they come
from Warcraft III and later. Keep them (they are useful), but they are 2002, not 1998.

### 2.3 Chapter prose

Mostly sound. Three habits to cut:

- **Fragment-as-thesis.** "Kessler-Hayashi's sky." "The culture's furniture." "Grubstake keeps its books in its head."
  "Its guns come down from orbit, so there is no truck to stop." The last is good (a fact with a consequence); the first
  three are the manual winking at the reader.
- **The explanatory colon chain.** "It plans from orbit: it knows your defenses before it sets out." "A rival steals:
  raids where no turret covers, skims, strip camps, power taps and claims." A colon every third sentence is a
  signature; the period manuals use "which", "because", and full stops.
- **Epigrams in the openers.** "Kessler-Hayashi never forgets." "Grubstake keeps its books in its head." "Hold the
  line, then take theirs." The mottos are fine as mottos (C&C has "Brotherhood, unity, peace"); the trouble is that
  the chapter prose then keeps producing more of them.

### 2.4 What is *not* wrong

The restraint on exclamation marks and the absence of "epic" are right; the mechanics' second person is right; the
short declaratives in the Tips are right (C&C's tips read the same). The register problem is not that the book is
plain. It is that the plainness is uniform, and uniformity is the tell.

---

## 3. The pictures

### 3.1 What repeats

From `_generated/lp-data.json` and the chapter files:

| Image | Used where |
|---|---|
| `vistas/grubstake-wide.jpg` | cover strip, Grubstake opener (p. 27) |
| `vistas/serenity-wide.jpg` | cover strip, Kessler-Hayashi opener (p. 11) |
| `vistas/synthexis-night.jpg` | cover strip, Synthexis opener (p. 40) |
| `vistas/serenity-close.jpg` | figure in the Kessler-Hayashi chapter (p. 13): the same camp as the opener, closer |
| `vistas/synthexis-clinic.jpg` | figure in the Synthexis chapter (p. 42) |
| `vistas/player-base.jpg` | the army opener (p. 57) |
| `vistas/grubstake-close.jpg`, `synthexis-wide.jpg`, `serenity-wide.jpg` | the back cover strip repeats the three cover vistas |

So three vistas appear three times each (front cover, opener, back cover), and the Kessler-Hayashi chapter shows the
same camp twice within two pages. Eleven of the book's nineteen non-portrait images are of four camps.

### 3.2 What is unclear

Every clip and vista is **the same shot**: map-view zoom, straight down, mid-afternoon light, the same brown-green
palette, the subject small in the middle. Looked at as pages:

- **p. 8, the landing**: a dust cloud and a crater with three small blue shapes at the right. The caption says a lander
  "just down"; the picture shows the explosion. The lander itself, the thing the caption names, is the least visible
  object.
- **p. 15, the drop-siege**: an acre of sand, five yellow sparks in a column, a dark smear of units at the right. The
  caption tells you the sparks are guns deploying; nothing in the frame does.
- **p. 16, the orbital strike**: the book's centrepiece event is a black blob with yellow dots on dark grass. The
  spotter's beam, the rings, the platform's shadow, the lances falling "outward along the wall" (the mechanic the text
  spends a paragraph on) are not legible at 50 mm wide in print.
- **p. 31, the Grubstake siege column**: a camp (again), with dots. The howitzer truck "at the right" is a dot.
- **The unit portraits**: 240 px top-down sprites on a grass square, the same angle for all 44, dim. The biters are
  small on grass and the four Synthexis biters are the same silhouette in four sizes. StarCraft's unit art was a 3/4
  view sprite with a painted portrait of the *face*; C&C's was a render on white. A top-down sprite is the one view
  that never shows what a unit looks like.

Period manuals never ran a wide, unannotated gameplay screenshot as a figure. When they showed the game, they showed it
**to teach the screen**, with leader lines and labels, and they showed things **to look at** as art: renders, drawings,
portraits.

### 3.3 What to shoot or make

The game can film anything (`/lp` dev tools, `scripts/showcase.sh`, the trailer stages `teslawall`, `warfinale`,
`dome`, `herd`, `farm`, `trailer`), there are Blender scripts for the Kessler-Hayashi guns, the jammer mast, the tesla
tower, the uplink and the player's army (`tools/blender/`), and the sprite sheets are in `landing-party/graphics/`.
Concretely:

1. **Replace the unit portraits with renders on a neutral ground.** For every unit that has a Blender source, a 3/4
   view at a fixed camera, a drop shadow, no terrain: C&C's convention. For the tinted vanilla units (troopers, tanks,
   biters) a 3/4 crop of the sprite sheet's best frame (`graphics/*/`, the sheets have 3/4 directions) at 2x, on the
   same neutral ground, so the whole bestiary shares one angle and one light. The Synthexis breeds then differ by
   colour and shape rather than by size alone. Keep the 240 px square; change what is in it.
2. **One hero image per faction that is not a camp.** The opener's vista is the only place the wide shot earns its
   width, and it should be of the faction's *signature event*, not its yard: Kessler-Hayashi's lander coming down on
   its thruster flame with the pods streaking (the trailer's landing beat, at the frame where the hull is ten tiles
   up), Grubstake's hauler lit by headlights beside a belt at night with the gaps downstream (the skim), Synthexis's
   wave pouring through a gap with the burster's ring on the ground. Then the cover strip can keep the three camps,
   and nothing repeats.
3. **Zoom in by two to three for every clip.** Factorio's `game.take_screenshot` takes a `zoom`; the clips are at map
   zoom. At zoom 2 the drop-siege's guns are guns, the mortar's shell is a shell, the spotter is a figure. Shoot at
   noon (the night shots are mud in print) unless the night is the subject.
4. **Annotate.** The template has `.tree` and `.pullquote`; it needs a `.figure-callouts` form: numbered dots on the
   image and a numbered caption list below (the Homeworld/C&C leader-line convention, which is also how Factorio's own
   wiki annotates). The pages that want it: the Kessler-Hayashi camp (lander, generators, dome projector, the three
   labs, the yard, the first arc of the line), the siege (escort ranks, mortars, howitzer, mast, spotter), a Synthexis
   culture (incubator, biochamber, tumor, creep edge, clinic, heating tower), a Grubstake claim (stake, rig, bins, the
   road). One annotated plan per faction replaces three unannotated screenshots each.
5. **Sequence strips for the two-step events.** The orbital strike as three frames across the page: paint (the red
   beam and rings), the shadow passing, the lances along the wall. The landing as three: pods, shadow, hull on the pad.
   The burster's wind-up as three: run, swell, burst. A single frame of a timed event never reads; three do.
6. **Crop to one unit for the card's second picture.** If the card keeps a screenshot, make it a 2x crop of one unit
   doing its thing: a lightning tank's arc jumping along three laser turrets; a dozer's blade at a wall; a scout's
   skull marker where it fell. The caption then says one thing and the picture shows it.
7. **Drop the back-cover strip's repeats**, or make the back cover the one place the four factions' *portraits* (a
   trooper, a shotgun hand, a bred big biter, the engineer's trooper) sit side by side at the same scale.

---

## 4. Rules for the rewrite

### 4.1 Lore

1. **Pick a document, not a narrator.** Each lore page is a found document with a header: an intelligence file
   (Kessler-Hayashi), a prospectus or a claims ledger (Grubstake), a leasing audit or an ethics-committee minute
   (Synthexis), a freight register's reclassification notice (the system page). Third person is kept because the
   documents are institutional; the detachment goes because every document has an author who wants something.
2. **A proper noun or a number in every second sentence.** Names of people (two per faction, one who signs and one who
   is in the field), stations, ships, contracts, clauses, sums, counts. Fake precision is the period's texture:
   "486.2 billion Swiss Francs", not "considerable assets". The template's `digit` guard applies to `words.cfg`, not to
   the chapter files, so lore pages may carry numbers; the rule that numbers come from the code applies to numbers the
   code holds. A contract's clause number and a platform's count are not in the code and are the writer's.
3. **No paragraph ends on an aphorism.** End on a fact, a name or a consequence. One epigram per page, and it goes in
   the pull quote, attributed to a named person with a reference.
4. **Give the narrator an interest.** The file-writer is wary; the prospectus is salesmanship; the audit is dry
   disapproval. Adjectives are allowed again when they are the narrator's opinion ("shady", "clumsy", "tired").
5. **Mechanics as hardware, not as rules.** "A branch stops when its lab is gone" becomes a thing about the company
   (its research staff are on the ground, in three buildings, because the ring will not host live weapons work). The
   invoice post is a billing practice with a clause number. The line is a surveyed boundary with a legal name.
6. **Vary the sentence.** At least one sentence per paragraph that opens on a subordinate clause; at least one that is
   long. Cut every "X, and Y" where a "because", a "which" or a full stop would do.
7. **Ban list** for lore: pressure, planned, reads (as "is read as"), worth having, the way most places do, the whole
   skill, "does not say", "nothing lived", "for a long time". No fragments as sentences. No tricolons. No "not X but
   Y".

### 4.2 Unit blurbs (`words.cfg`)

1. **The unit is the subject of the first sentence**, as a thing: its make, its kit, its temperament. Not when it is
   fielded (the tree says that), not what the planner does with it (the chapter says that).
2. **Name the hardware.** A pattern name, a maker's model, a breed's lineage (StarCraft's "Core Genus"). `words.cfg`
   stops on a digit, so designations are letters: "the Okonkwo-pattern suit", "Mark Two" spelt out, "the Zz'gashi
   line".
3. **One sentence of advice in the second person**, as C&C does ("Make sure you have excess power before building
   these"), and it is the only place the blurb may say "you".
4. **Each blurb a different shape.** No two cards of a faction open with the same construction. Read the twelve in a
   row before committing.
5. **Keep counters and countered-by**, but move the research trigger out of the blurb and into the card's `Era` line
   ("Era 2, Optics lab" already carries it).

### 4.3 Chapter prose

1. Colons at most once a paragraph; no fragment sentences; openers' one-line summaries are facts, not mottos.
2. Keep the second person and the numbers; they are the book's strength.
3. Where the lore page has named a thing (the ring, the clause, the line's legal name), the chapter may use the name
   once, in parentheses, and then the plain word.

### 4.4 Layout

1. **A dossier block** at the top of each lore page: five to seven capitalised fields (the Westwood form), then the
   prose. The template gains a `.dossier` div rendered as a two-column definition list in the display face.
2. **Pull quotes attributed to a named person with a reference** (name, post, document, date in the world's own
   count).
3. **Unit cards**: a render in 3/4 on neutral ground; keep the bars (they are a 2000s habit, but the user wants them and
   they read well); the blurb above the bars as StarCraft does (Role, Armament, then text), the counters below.
4. **Figures**: annotated plans with numbered callouts, sequence strips for timed events, 2x crops for single units;
   no unannotated wide shots in the chapters.
5. **The frame.** The faction's colour bar on the fore-edge is the book's one piece of period furniture and it is
   good. The lore pages could take one more: a faint document texture (a form's ruled lines for the file, a ledger's
   columns for the prospectus) under the dossier block, in the faction's tint, as StarCraft framed each race's pages
   in its own metal.

---

## 5. Samples

### 5.1 Kessler-Hayashi, "The contract", rewritten

Everything below is consistent with what the mod does (the landing in pods, generators holding the lander, the dome,
the three labs, the line's arcs and warnings, the invoice post and truce, the spotter and the strike, the uplink and
the withdrawal, the armed landing from the late era, the war with Grubstake, the stand-down and the new landing). The
names (Serenity Ring, Kessler, Hayashi, Okonkwo, the clause numbers, the counts of platforms and escorts) are mine and
are placeholders for the user to keep or replace; "Serenity" is the faction's internal id and makes a good name for
its station. The dossier block assumes a `.dossier` div; until the template has one, the same lines render acceptably
as a bold-label list.

```markdown
::: {.lore kicker="Freight Authority file" title="The contract" faction="kessler-hayashi"}

::: {.dossier}
KESSLER-HAYASHI SECURITY
: Commonly K-H; "the landlord" among Grubstake crews; "the contractor" in the engineer's radio log.

REGISTERED
: Serenity Ring, nine armed platforms on a leased orbit that moves to wherever the client is paying. No ground
  holdings, by policy.

PRINCIPALS
: Ilse Kessler, Director of Field Operations (the one signature on every site report).
  R. Hayashi, Comptroller (never seen on a surface; signs the invoices).
  Tomas Okonkwo, Chief of Siege Works, Nauvis site.

CONTRACTS KNOWN
: Freighter escort on the Aquilo run, four gunships per convoy, since the second ice season.
  Cordon duty at the Vulcanus foundries while the worms pass, billed by the hour.
  Nauvis: contract NV-1, client withheld under clause 9.

MILITARY STRENGTH
: Troopers in laser kit, tanks, railgunners for the local fauna; laser drones from the second shipment. Heavier
  patterns are built on site, in three laboratories, and only while those laboratories stand.

SEE ALSO
: Grubstake Mining (dispute, ongoing); the engineer (listed as site hazard, class three).
:::

Contract NV-1 was signed the week the engineer's first rocket cleared the atmosphere. Nobody on the Ring will say
who signed it, and the clause that hides the client is the one clause the company has never waived. What the
contract buys is easier to find out, because Kessler-Hayashi does everything in writing: a surveyed boundary round a
landing site, the launch lanes above it, and "protective custody" of any cargo that leaves the ground inside the
boundary. The engineer's rockets are cargo. The engineer is a hazard.

A K-H site arrives finished. The lander comes down inside a cargo pod with the escort's pods on either side, and
then six more pods, and by the time the dust has settled there are generators round the hull, a dome projector
humming over it and a wall going up. Director Kessler's crews rebuild the generators before anything else, because
the lander's anchors are powered and a lander with half its generators dark can be taken apart with hand tools.
The laboratories come later, each in its own walled district, because the Ring's insurers will not carry live
weapons research in orbit: Optics, the Armory, and Okonkwo's Siege Works, which is the one the engineer learns to
fear.

::: {.pullquote cite="I. Kessler, site report NV-1/3, countersigned R. Hayashi"}
Site hazard notified of its obligations under clause twelve. No reply. Billing continues.
:::

The boundary is the Director's instrument. Her drones pour a pad, raise a short wall facing the engineer and set
two guns on it, and the survey office posts a notice naming the building that the next arc will enclose. Across a
railway the arc carries a gate, and the gate is shut. Belts and pipes that cross the surveyed edge where her guns
stand are cut as encroachments. Clause twelve bills the engineer for every nest that attacks a K-H camp out of the
engineer's own smoke; the invoice stands on the boundary, the sum is posted in circuits, and a paid invoice buys the
one thing the company sells cheaply, which is quiet. When a wall will not come down under Okonkwo's mortars, a
trooper walks up to it with a painting laser and the platform overhead does the rest. The company has lost sites
before. Where its uplink is destroyed it stops paying for the ground, pulls the weakest camp first, and files
Nauvis under "written off", with the client's name still blacked out.
:::
```

Word count about 560 with the dossier, against the current 330; the dossier block sets in the display face at a
smaller size and the page is A5, so this is a page and a half. Either the lore pages become a spread (which the period
manuals' histories were: StarCraft's run twenty pages) or the second and third prose paragraphs are cut to one. I
would make it a spread: the lore is the part of the book the user wants to be an object.

What changed, against the rules: a document with a header and fields; nine proper nouns and seven numbers where there
were none; the narrator is the Freight Authority's file clerk and is wary ("the one the engineer learns to fear",
"with the client's name still blacked out"); no paragraph ends on an aphorism (they end on a fact or a name); mechanics
are stated as the company's practices and the hardware's properties (powered anchors, insurers, a survey office, clause
twelve); the pull quote is a real document line from a named person; sentences vary in length and open on subordinate
clauses; the two-beat seesaw is gone.

### 5.2 Three unit blurbs, rewritten

For `words.cfg` (no digits; the research trigger leaves the blurb because the card's Era line carries it).

Current, `lp-lance` (Heavy laser trooper): "Fielded once your infantry has cost Kessler-Hayashi enough. Its beam
reaches past your troopers', so a trooper line that won the last fight loses the next."

> lp-lance=The Lance pattern is a laser trooper's suit with the Optics lab's long emitter bolted where the rifle was,
> and a cable to a pack that weighs more than the trooper. The beam reaches a good way past a submachine gun's, so
> the Lance stands off and fires while your troopers walk into it. Close the distance with vehicles or take the
> Optics lab, which is where every Lance is calibrated.

Current, `lp-grubstake-buggy`: "Fast, light and everywhere. Most of what Grubstake takes from you, it takes with
buggies, and the buggy circling just outside your guns is its prowl."

> lp-grubstake-buggy=A Grubstake buggy is a car frame, a machine gun on a pintle and whatever panels the yard had
> that morning; no two are the same colour under the amber. Crews drive them out at dusk to circle a factory just
> beyond the guns and note what stands unguarded, and the raid that follows goes where the buggy went. A buggy you
> kill on its circuit teaches the next driver to keep wider of that spot, so kill it somewhere you can afford to
> leave open.

Current, `lp-bred-cinder` (Synthexis burster): "Bred for walls that have held. It runs to the wall and bursts there,
and a well-aimed group takes the corner turrets with it."

> lp-bred-cinder=Synthexis's clinic breeds the burster from the small biter's line with the jaws grown out and the
> acid gland grown in, until the animal is a running sac that cannot feed and lives a few minutes after it leaves the
> incubator. It makes for a wall, stops, swells, and goes off; killed on the way it goes off where it dies. Turrets set
> a few tiles back from the wall take less of the blast, and a burster that has stopped to swell is already lost to
> you, so your fire belongs on the ones still running.

Each opens with the unit as a made thing with a lineage; each names hardware or biology (the Optics lab's emitter, a
pintle, the small biter's line); each gives one piece of advice in the second person and otherwise keeps "you" out;
none restates the research trigger; the three have three different shapes.

---

## 6. Order of work

1. Template: `.dossier` div (two-column definition list, display face), a `.figure-callouts` form (numbered dots on an
   image, numbered caption list), lore pages allowed to run to a spread.
2. The four lore pages, in the register of 5.1, each as a different document type; names agreed with the user first,
   since they will leak into the chapter prose and the locale.
3. `words.cfg`: all 44 blurbs by the rules in 4.2, read in a row per faction before committing; the roles for the
   bred biters likewise.
4. Chapter openers and the fragment/colon pass over the chapter prose (an hour's work; the mechanics prose otherwise
   stays).
5. Pictures: unit renders first (they touch every card page), then one hero event per faction, then the four
   annotated plans, then the three sequence strips.

Sources, for the record: C&C manual text at `cnc-comm.com/files/CC-Manual.pdf`; StarCraft at
`archive.org/details/manual_Starcraft`; Warcraft II at `archive.org/details/warcraft-2-battlenet-edition` and
`warcraft.wiki.gg/wiki/Warcraft_II_manual`; Red Alert at `archive.org/details/ccredalertreferencecards`; Homeworld at
`archive.org/details/Homeworld_Manual` (gameplay guide only); Dark Reign expansion at
`archive.org/details/dark-reign-expansion-manual`; Age of Empires at `archive.org/details/manual_Age_of_Empires`;
Total Annihilation's story from the user's guide mirrored at `discmaster.textfiles.com` (the jewel-case manual at
`archive.org/details/total-annihilation-game-manual-jewel-case-1997` has no lore). Local copies and page renders are in
the session scratchpad under `dl/` and `voice/`.
