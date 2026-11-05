# The manual's cast (2026-11-05)

Every name below is invented for the lore pages. Everything is tied to a thing the mod does (in brackets where it is
not obvious). Ship and platform names are in italics. Two existing names carry a flag: *Serenity* is Firefly's ship
(kept because it is the faction's internal id and the user cited the sample as the model) and *Okonkwo* is Achebe's
protagonist (replaced by Adeyemi). Canon kept: five planets, platforms, the engineer unnamed; no faction native to a
planet.

The user's calls (2026-11-05): the night foreman renamed (was Dagny Holm, now Marit Holm); Kessler-Hayashi remixed
as a conglomerate whose security division is one arm, with a slogan, numbered directives and a quieter interest
behind its Nauvis contract (below, "Kessler-Hayashi"); the Comptroller dropped as a character: invoices go out under
the company's name, and Hayashi stays on the letterhead as the founding family only.

## The system: the Freight Authority (keeper of the files)

| Who or what | One line |
|---|---|
| **The Freight Authority** | Registers lanes, surfaces and operators, clears lane fees, keeps the operator files the lore pages are. It has a form for everything and no guns. |
| *Clearing House* | Its registry platform on the inner lanes; every operator's address of record is a box here (Grubstake's is only that). |
| **Mirela Tanase**, Clerk second grade, Lane Registry | Writes the histories. Has read three operators' paperwork and trusts none of it; the wary voice of the chronicle parts. |
| **Registrar O. Brandt** | Signs reclassifications and never a history; initial only, as the forms print it. |
| Survey tender *Carrow* | Authority hull lost over Nauvis before the engineer; its wreck is the one the engineer's first radar charts (the Signs mechanic). |
| Lane Registry, Nauvis sheet | The register entry the index page reproduces: "uncharted, hazard" until a cargo rocket leaves the surface. |
| Form LR-7, Reclassification of a Surface | The notice "Surface activity confirmed. Reclassify as commercial.", signed Brandt (now attributed). |
| Operator files 114, 209, 377 | Kessler-Hayashi, Grubstake, Synthexis: the dossier blocks at the top of each faction's lore page. |
| Hazard register, entry H-3 (Nauvis) | The engineer: "operator, unregistered"; the Authority's only name for the player. |

## Kessler-Hayashi (operator file 114)

A conglomerate, not a security firm. The Security Division is the arm that lands; the rest of the company rides the
lanes. The inspiration is Weyland-Yutani's shape (a bland parent, cold directives, a contract that covers a quieter
interest); nothing is lifted from it.

| Who or what | One line |
|---|---|
| **Kessler-Hayashi** | The parent: Hayashi Lane Assurance, a lane-insurance house, took the Kessler name with the gunship fleet it bought to stop paying out on the Aquilo run. Four divisions: Freight, Orbital Works, Survey, Security. The Hayashi family keeps the chair and appears on the letterhead only; no Hayashi has sat in a field office. |
| Slogan | "A quieter system for everyone." On every letterhead, the notices of the line included. Its field motto stays the game's: "Please remain behind the line." |
| **Standing Directives** | Numbered company rules, quoted in its filings. SD 4.1: a site's lander and its generators are company assets of the first class, restored before personnel are relieved (crews rebuild generators first; the lander stands while half of them do). SD 6.2: live weapons research is conducted on the contracted surface and never aboard a company hull (the three labs on the ground; a branch stops with its lab; Keel & Ward will not carry it). SD 9: observations of a contracted surface are company property and are disclosed to no client, operator or registry (its orbital intelligence). SD 11: a site whose uplink is lost is written off, and personnel on it are carried at book value until the write-off clears (withdrawal: the weakest camp falls first, nothing rebuilt). |
| The quieter interest | Contract NV-1 buys launch-lane security and "protective custody" of cargo leaving the surface. What the Ring files to the parent each period is not launch counts: it is the Survey Division's read of a working factory nobody paid to build. In the mod: Kessler-Hayashi reads the player's defences from orbit when it plans a siege and sizes the siege by what it reads (shared.CORPS orbital_intel; siege.lua read_size), surveys the power behind the turrets facing it for the one pole to cut (power.lua), measures the player's research to match its own (the eras), and clears Synthexis's incubators as nests (clears_nests). Nothing is dismantled or carried off: Kessler-Hayashi destroys, Grubstake takes apart (ops.lua, temper.loots). |
| **Ilse Kessler**, Director of Field Operations, Security Division | The one signature on every site report; runs Nauvis from the Ring, lands never. (Kessler syndrome: orbit.) |
| **Tomas Adeyemi**, Chief of Siege Works, Nauvis | Runs the Siege works lab and the mortar and howitzer columns; was Okonkwo in the sample. |
| **P. Lindqvist**, Surveyor, Survey Office | Posts the boundary notices ahead of each step of the line. |
| **M. Voss**, Fire Controller, *Quiet Enjoyment* | Signs strike orders; the painting laser's beam goes to this platform. |
| **Keel & Ward**, the Ring's underwriters | Will not carry live weapons research aboard: SD 6.2 was written to keep their cover. |
| Accounts | Invoices and the write-off memorandum issue under the company's name, unsigned. (The Comptroller, dropped.) |
| **Serenity Ring** | Nine armed platforms on a leased orbit that moves to the client; no ground holdings by policy. (Internal id; Firefly flag.) |
| *Clear Title* | The Ring's office hull: the Director, Accounts, the Survey Office. (Legal term.) |
| *Quiet Enjoyment* | The hull over Nauvis: fire control, strikes, the siege pods it drops on a held site. (Lease law: the tenant's right to quiet; what a paid invoice buys.) |
| The Aquilo run, the Vulcanus cordons | Its other contracts: four gunships a convoy on the ice run; cordons round the foundries while the demolishers pass, billed by the hour. |
| Contract NV-1 | Nauvis. Client withheld under clause 9; the one clause it has never waived. Site reports numbered NV-1/n. |
| Schedule B, the Secured Perimeter | The line's legal name; each arc a Schedule B notice; a border stake is a boundary filed under it, refused from an enemy. |
| Clause 12 | Bills the operator for every nest that attacks a K-H site out of the operator's smoke: the invoice post, paid in circuits, modules or steel; a settlement buys a truce. |
| Works orders, strike orders QE-n | Adeyemi's sieges and Voss's strikes; the spotter is "the painting party". |
| Write-off memorandum | Issued by Accounts when the uplink falls, under SD 11: Nauvis written off, the client still blacked out. |

Dossier header: KESSLER-HAYASHI SECURITY, COMMONLY, PARENT, REGISTERED, PRINCIPALS, DIRECTIVES CITED, CONTRACTS
KNOWN, MILITARY STRENGTH, SEE ALSO.

## Grubstake Inc. (operator file 209)

| Who or what | One line |
|---|---|
| **Augustin Pell**, Managing Partner | The grubstaker: signs the Articles and every salvage purchase, has not stood on a claim in years. (Grubstake: a prospector's loan.) |
| **Nadia Szabo**, Claims Agent, Nauvis | Posts the stakes, files the ten-minute notices, signs the Nauvis book of the register; the lander's only officer. |
| **Marit Holm**, Night Foreman, Nauvis yard | Runs after-hours recovery: skims, taps, snatches, the jumper's tunnel; trucks out at dusk, back at dawn. (Thieves' hours.) |
| **Dr. H. Ness**, field biologist, on contract | Built the pacifier antenna from a gland; keeps the Arrangement with the biters; Grubstake's only scientist. |
| No home port | Address of record: box 2210, *Clearing House*. The fleet is the company. |
| *Tailings* | The lander hull that puts camps down; tired, patched, amber. (Mining: the waste heap.) |
| *Assay* | The survey tender; its party of a radar, two drills and guards is what lands at oil processing. (Mining: ore testing.) |
| Calder Foundry, Vulcanus (in receivership) | The foundry company that went under; Grubstake bought the slag and the cranes and lifted both within the year. |
| Fulgora, Lot 9 | Scrap rights held one storm season and sold on. |
| The Articles of Grubstake Inc. | Its charter: a partnership to follow rushes, buy rights and work claims. |
| Register of Claims, Nauvis book | Every claim stake; the player's Claims register research reads it. |
| Notice of Intent to Claim | The prospect notice; the stake's lamp runs out when the notice does. |
| Recovery notice | "Grubstake Inc. has recovered 4,000 iron ore from an unattended deposit"; its voice for a raid. |
| The Salvage Convention, article 4 ("unattended") | Its reading: a machine no gun covers is abandoned; ore no drill works is unclaimed. |
| The Arrangement | The pact with the biters; no paper exists; the player's pact breaker jams it. |
| Trade post receipt | "Consideration received"; a truce. |
| The unmetered connection | What its books call a power tap. |

Dossier header: GRUBSTAKE INC., COMMONLY, REGISTERED, PRINCIPALS, CLAIMS WORKED, CLAIMS CURRENT, FLEET, LIABILITIES,
SEE ALSO.

## Synthexis (operator file 377)

| Who or what | One line |
|---|---|
| **Dr. Anouk Verhaegen**, Principal Investigator, Nauvis trial | Signs every batch release from the clinic; the one name the company discloses. |
| **Ilya Rask**, Senior Technician | Walks the rounds between the towers and the biochambers; the feed roster is his; the culture raises more technicians as it grows. |
| **Principals** | Not disclosed; correspondence through the lessee's agent on Gleba. Origin left unsaid, as briefed. |
| Gleba, swamp lots GL-22 to GL-26 | Its leases, filed with the Authority's Surface Registry: yumako, jellystem, pentapod study. A link, not a home. |
| *Cold Chain* | Its platform: ships substrate, seed stock and the clinic to a trial site before they spoil; a young culture's clinic comes down from it by pod. (Spoilage.) |
| The Nauvis trial site | "Synthexis culture n" on the map; incubators, biochambers, tumors, the heating tower and clinic on a blot of Gleba soil. |
| Trial Protocol NV/1 | An open-air breeding trial on wild stock; the control is "the unregistered operator's works". (Waves as trials.) |
| Batch release note | One per wave, signed Verhaegen: breed, count, target, gate. |
| Adverse event report | A wave lost; the dry voice of learning. |
| Carrier dispatch | A founding carrier sent to a new field; the lit violet one with the escort. |
| Feed roster | The technicians' rounds; a biochamber unvisited stops. |
| Surface Registry audit minute | The Authority's: the Gleba leases do not cover Nauvis; no licence for Nauvis exists; no action taken. |

Dossier header: SYNTHEXIS, COMMONLY, REGISTERED (lessee of record), PRINCIPALS, LICENCES (Gleba: five lots; Nauvis:
none), PRODUCT, STAFF ON SURFACE (technicians; no armed personnel), SEE ALSO.

## What they call each other

| | Kessler-Hayashi | Grubstake | Synthexis | The engineer | Wild biters |
|---|---|---|---|---|---|
| **In K-H filings** | | "the scrap trade"; "trespass" | "unlicensed pest control"; "the growers" in the field | "the site hazard, class three" (SD 9: never "the client's") | "local fauna" |
| **In Grubstake's books** | "the landlord"; "the rent" | | "the greenhouse" | "the mark"; "the unattended operator" in notices | "the neighbours" |
| **In Synthexis papers** | "the exterminator" | "the supplier" (its smoke feeds the culture) | | "the control" | "wild stock"; "the hedge" |
| **At the Authority** | "K-H" | "the outfit"; box 2210 | "the lessee" | "the unregistered operator" | "the indigenous hazard" |
| **In the engineer's radio log** | "the contractor" | "the scrappers" | "the stripes" | | |

## Where the names will reach

The lore pages and their pull quotes first. Then at most one use each in the chapter prose (the Schedule, clause 12,
the Arrangement, the trial) and nothing in the locale until asked: the game's own names (Invoice post, Claim stake,
Synthexis culture) stay as they are.
