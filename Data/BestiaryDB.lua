--[[
    Forever Safari: Bestiary Database (Azeroth Field Pokédex)
    Dynamic Master Species Catalog aggregated directly from CreatureDB (2,000+ entries)
    Provides deterministic Pokédex numbering, 3D display info, native habitats,
    base stats, natural movepools, diet sustenance, and Nesingwary field lore.
]]

local addonName, ns = ...
ns = ns or {}
ForeverSafari = ns
ns.BestiaryDB = ns.BestiaryDB or {}

local Bestiary = ns.BestiaryDB
local FS = ns

-- Handcrafted Nesingwary field notes & lore archives
Bestiary.LORE = {
    ["Agam'ar"] = "Ancient quillboar war-beast infused with the divine blood of Agamaggan.",
    ["Aku'mai"] = "Ancient multi-headed terror of the Old Gods, lurking within the submerged ruins of Blackfathom.",
    ["Alarm-o-Bot"] = "High-decibel intruder detection bot that alerts surrounding mechanoids while emitting disruptor pulses.",
    ["Ancient Kodo"] = "Venerable dying giant making its final pilgrimage to the sacred bones of its ancestors.",
    ["Anodized Robo-Cub"] = "Chromed mechanoid bear crafted by master Tinkers, featuring insulated thermal plating.",
    ["Araga"] = "Rare mountain cougar inhabiting the snowy ruins and high passes of Alterac.",
    ["Arcane Nullifier X-21"] = "Experimental antimagic drone projecting dampening forcefields that absorb spell damage.",
    ["Arcane Sentry"] = "Ancient titan-forged stone automaton powered by eternal arcane matrices.",
    ["Arra'chea"] = "Colossal elder kodo bull roaming the plains of Mulgore, leading ancient migration herds.",
    ["Azure Whelpling"] = "Magical broodling of the Blue Dragonflight, radiating frosty arcane luminescence.",
    ["Azzere the Skyblade"] = "Azure feathered serpent soaring gracefully over the Great Divide.",
    ["Barnabus"] = "Notorious apex worg stalking the arid canyons of the Badlands with ironclad endurance.",
    ["Barnacle Bludgeoner"] = "Armored reef crab encrusted in sharp barnacles that tear into attacking claws.",
    ["Bellygrub"] = "Legendary corpulent boar that eluded Redridge safari hunters for over a decade.",
    ["Bhag'thera"] = "Deadly shadow panther hunted by Hemet Nesingwary for mastering supreme jungle stealth.",
    ["Bjarn"] = "Legendary pure-white bear celebrated by dwarven mountaineers for indomitable strength.",
    ["Black Bear"] = "Sturdy omnivores with thick hides, weathering heavy punishment while mauling foes with sweeping paws.",
    ["Black Whelp"] = "Cruel progeny of the Black Dragonflight, exhaling searing brimstone fire upon mortal foes.",
    ["Blazing Elemental"] = "Sentient living flame birthed from the molten magma vents of Blackrock Mountain.",
    ["Blazing Inferno"] = "Furious firestorm entity raging endlessly among the ruins of the Dark Iron empire.",
    ["Blight Stalker"] = "Stealthy unholy predator hunting through ruined grain silos infected with blight cauldrons.",
    ["Blightcaller Bat"] = "Venomous carrier bat infected with fungal spores that rot living tissue on contact.",
    ["Bloodaxe Worg"] = "Trained war worg of the Dark Horde, bred for merciless pit combats and armored warfare.",
    ["Bloodseeker Bat"] = "Prized sacrificial bat worshipped by High Priestess Jeklik and blood trolls.",
    ["Bloodtalon Raptor"] = "Intelligent, sickle-clawed reptiles that hunt in pack formations with surgical lethality.",
    ["Bone Golem"] = "Towering juggernaut constructed from thousands of fused humanoid and animal bones.",
    ["Bristleback Boar"] = "Desert swine with sharp defensive back quills trained to protect Quilboar thorn dens.",
    ["Broken Tooth"] = "Legendary Badlands stalker renowned across Azeroth for blinding 1.0 attack speed and ruthless precision.",
    ["Carrion Beetle"] = "Burrowing insect created from Crypt Lord carapaces, swarming corpses in subterranean tombs.",
    ["Carrion Vulture"] = "Hardy scavengers circling thermal drafts above desolate battlefields and arid deserts.",
    ["Cave Creeper"] = "Blind subterranean spider navigating dark mine shafts using sensitive leg hairs.",
    ["Cavern Geode"] = "Crystal-studded earth creature whose hollow interior reverberates with magical harmonies.",
    ["Cinder Sprite"] = "Playful but deadly spark spirit fluttering above rivers of boiling lava.",
    ["Cinderweb Spinner"] = "Fire-resistant arachnid spinning flaming web strands across volcanic chasms.",
    ["Claw Lord"] = "Monstrous giant crab dominating the rocky shores of the Bay of Storms.",
    ["Clockwork Gnome"] = "Intricate wind-up automaton built with precision brass gears and miniature defensive tools.",
    ["Clutchmother Zavas"] = "Monstrous red scorpid matriarch brooding over primal insect hives in Un'Goro Crater.",
    ["Coast Crawler"] = "Heavy-shelled tidal crustacean with pinching claws and high defensive shell integrity.",
    ["Compact Harvester"] = "Miniaturized harvest golem deployed in narrow mine tunnels to guard Defias foundry vaults.",
    ["Corrupted Fire Spirit"] = "Green fel-fire elemental born of apocalyptic infernal meteor impacts.",
    ["Coyote"] = "Scrappy, cunning scavengers capable of outrunning larger predators with sudden bursts of speed.",
    ["Crag Boar"] = "Tough, belligerent grazers equipped with razor tusks and an ironclad charging skull.",
    ["Crawling Claw"] = "Severed skeletal hand skittering across cobblestones with supernatural necrotic energy.",
    ["Crowd Pummeler"] = "Heavy-duty riot control automaton armed with hydraulic hammer fists.",
    ["Cursed Ghoul"] = "Famine-crazed flesh eater gnawing on ancient roots beneath Morbent Fel's tower.",
    ["Dart"] = "Extremely swift swamp raptor known for evading pursuers through dense marshlands.",
    ["Death Flayer"] = "Notorious black-chitin scorpid roaming the dry crags of Durotar, feared by young Orc recruits.",
    ["Deathmaw"] = "Volcanic black worg prowling the ash wastes around Blackrock Mountain with blazing fury.",
    ["Decaying Horror"] = "Twisted cadaver monster lumbering through the pine shadows near Pyrewood Village.",
    ["Deviate Cloud Serpent"] = "Warped serpent glowing with nightmare dream-mist, floating without flapping its wings.",
    ["Deviate Slayer"] = "Mutated emerald raptor infused with the nightmare energies of Naralex.",
    ["Diseased Wolf"] = "Mangy timber wolf transformed into a feral necrotic carrier by Scourge taint.",
    ["Dishu"] = "Rare cheetah with shimmering spots sprinting through the Southern Barrens oasis valleys.",
    ["Dread Gargoyle"] = "Stone-skinned airborne demon of the Scourge, descending from gothic spires to rip prey to shreds.",
    ["Dread Swoop"] = "Fierce predatory bird executing diving ambushes from high desert thermals.",
    ["Dreadmaw"] = "Fierce marsh crocolisk that ambushes travelers along the old sunken road.",
    ["Duskbat"] = "Blind nocturnal mammal navigating by screeching echolocation, draining blood from prey.",
    ["Duskstalker"] = "Ghostly black saber cat hiding in the shadow glades of Teldrassil, elusive to novice hunters.",
    ["Dust Devil"] = "Whirling miniature cyclone sweeping through farmsteads, blinding travelers with grit.",
    ["Earthcaller Shard"] = "Emerald crystal elemental awakened by reckless jungle gold prospecting.",
    ["Elder Mountain Boar"] = "Veteran swine with hardened tusks capable of uprooting sturdy ironwood stumps.",
    ["Elder Nightsaber"] = "Battle-tested predator of ancient Kalimdor, sporting deep claw scars from demonic wars.",
    ["Emerald Whelpling"] = "Dream-warden whelpling guarding the passage into the Emerald Dream from the Sunken Temple.",
    ["Encrusted Tide Walker"] = "Vigorous water elemental cloaked in sea foam and crushing tidal waves.",
    ["Fleeting Plainstrider"] = "Long-legged flightless bird capable of outpacing wild horses across the wide open plains.",
    ["Forest Spider"] = "Eight-legged web-spinners paralyzing prey with neurotoxins before wrapping them in silk.",
    ["Frostfeather"] = "Glacial owl possessing ice-dusted wings that blend into snowy whiteouts.",
    ["Frostsaber Pride Watcher"] = "Majestic white-and-cyan saber cat guarding the sacred shrines of Frostfire Hot Springs.",
    ["Gahz'ranka"] = "Massive blue hydra lured from the depths of Zul'Gurub's river by Nat Pagle's special lure.",
    ["Gahz'rooka"] = "Ancient sea turtle summoned from the deep ocean using sacred Southsea kelp.",
    ["Geist Skulker"] = "Acrobatic hooded ghoul leaping between burning roofs in the dead city of Stratholme.",
    ["Gesharahan"] = "Savage water hydra worshipped by the Kolkar centaur tribes around the Barrens oases.",
    ["Ghaz'rilla"] = "Three-headed demigod hydra summoned from the sacred pool of the Sandfury trolls.",
    ["Ghostly Crab"] = "Ethereal translucent crustacean scuttling along the shores where ancient night elves drowned.",
    ["Glacial Water Spirit"] = "Sub-zero ice elemental forming razor icicles across freezing alpine lakes.",
    ["Goretusk"] = "Fierce long-tusked boar rooting through Westfall dirt, prized for rich succulent liver.",
    ["Gorgon'och"] = "Fearsome red alpha raptor leading hunting packs around the Fire Plume Ridge.",
    ["Granite Earth Spirit"] = "Ancient solid-stone spirit revered by the Tauren earthmother shamans.",
    ["Great Goretalon"] = "Giant mountain buzzard nesting atop the highest peaks of Render's Valley.",
    ["Greater Duskbat"] = "Large cavern bat hunting across the ruined orchards of Lordaeron.",
    ["Grizzled Ben"] = "Old grizzly known for outsmarting dwarven safari traps and fishermen around the loch.",
    ["Grizzly Bear"] = "Towering woodland juggernauts possessing immense brute force and unstoppable momentum.",
    ["Groddoc Ape"] = "Massive blue-backed ape dwelling in the ancient elven ruins of Feralas.",
    ["Harvest Reaper"] = "Upgraded harvest automaton equipped with dual whirling threshing scythes.",
    ["Harvest Watcher"] = "Rogue agricultural automations constructed by the Defias Brotherhood to patrol ruined Westfall farms.",
    ["Haunted Servant"] = "Apparition of Medivh's former palace attendants doomed to reenact banquet preparations.",
    ["Hayoc"] = "Mystical marsh dragon gliding silently across witch-haunted fen waters.",
    ["Highland Raptor"] = "Hardy highland predator equipped with heavy talons for hunting mountain rams.",
    ["Humar the Pridelord"] = "The regal black lion of the Barrens, commanding surrounding pride members with earth-shaking roars.",
    ["Iron Assembler"] = "Dark Iron foundry robot that welds steel plates onto damaged mechanized units.",
    ["Ironback"] = "Rare giant sea turtle with iron-hard dorsal ridges patrolling the Overlook Cliffs.",
    ["Ironbeak Owl"] = "Armored woodland owl with beaks hard enough to crack demon armor.",
    ["Ironfur Patriarch"] = "Ancient elder bear armored in dense matted fur that repels physical blows like iron.",
    ["Ironjaw Worg"] = "Armored mountain worg with a crushing bite capable of sundering plate armor.",
    ["Jungle Stalker"] = "Ferocious green-scaled jungle raptor revered by the Gurubashi tribes for pure predatory instinct.",
    ["King Bangalash"] = "The legendary white tiger monarch of Stranglethorn Vale, feared by hunters across the Great Sea.",
    ["King Mukla"] = "The colossal legendary ape king of Jaguero Isle, possessing mountain-crushing physical power.",
    ["Kodo Calf"] = "Heavy thick-skinned quadruped revered by the Tauren for loyalty, endurance, and crushing power.",
    ["Kresh"] = "Colossal ancient snapping turtle guarding the underground streams of the Wailing Caverns.",
    ["Kurmok"] = "Ferocious purple silverback ape stalking the mist-covered foothills of Kurzen's compound.",
    ["Kurzen Jungle Fighter"] = "Feral jungle cat captured and conditioned for pit combat by the rogue Kurzen forces.",
    ["Lashtail Hatchling"] = "Young raptor with whip-like tail reflexes, bounding through jungle undergrowth.",
    ["Lightning Hide"] = "Mottled yellow saurian possessing high electric potential in its rugged reptilian hide.",
    ["Living Flare"] = "Pure white-hot solar flare elemental radiating blinding incandescent heat.",
    ["Living Stream"] = "Pure crystalline water spirit guarding the ancient elven temple springs from twilight corruption.",
    ["Lord Incendius Spawn"] = "Direct fire spawn of Lord Incendius, guarding the sacred Black Anvil with incandescent fury.",
    ["Lupos"] = "Legendary spectral wolf of Duskwood said to infuse its fangs with pure shadow essence.",
    ["Magma Elemental"] = "Dense molten rock beast spewing incandescent lava torrents from its molten core.",
    ["Mangeclaw"] = "Battle-scarred white bear prowling the frozen ridges of Dun Morogh with ferocious tenacity.",
    ["Mazzranache"] = "Famous vibrant pink plainstrider racing across Red Cloud Mesa with unmatched swiftness.",
    ["Mecha-Crab Proto"] = "Gnomish deep-sea salvage unit featuring titanium pincers and watertight battery casing.",
    ["Mechanical Sentry"] = "Defensive perimeter drone firing pinpoint electrical sparks at intruders.",
    ["Mechanical Squirrel"] = "Nimble rodent mechanoid that scampers with hyperactive copper springs and chirping gears.",
    ["Mechanostrider Model B"] = "Gnomish bipedal transport prototype recalibrated for safari speed trials and terrain scouting.",
    ["Mist Howler"] = "Elusive grey wolf haunting the foggy borders between Ashenvale and the Barrens.",
    ["Mistvale Gorilla"] = "Immensely powerful silverback primates defending their jungle territories with ground-pounding fury.",
    ["Molten Golem"] = "Hardened basalt golem infused with molten lava veins, immune to physical bludgeoning.",
    ["Mother Fang"] = "Colossal mine spider matriarch nesting deep inside Elwynn's richest gold mine.",
    ["Mottled Boar"] = "The quintessential rite-of-passage beast for young Horde warriors training in Durotar.",
    ["Mottled Boar Hound"] = "Loyal tracking hound bred by Horde scouts to hunt boars and trail intruding scouts.",
    ["Mountain Lion"] = "Muscular ambush hunters stalking craggy ridges to leap upon unsuspecting quarry from above.",
    ["Naga-bred Hydra"] = "Savage sea hydra conditioned by Naga sirens to sink Alliance and Horde war galleys.",
    ["Naraxis"] = "Venomous broodmother dwelling in the gloomy webbed groves south of Darkshire.",
    ["Necro-Fiend"] = "Crypt fiend spider infused with ancient Nerubian mummification curses.",
    ["Nightsaber"] = "Stealthy apex predators prowling beneath the twilight canopy of ancient Kalimdor forests.",
    ["OOX-09/HL Mech-Chicken"] = "Lost high-frequency reconnaissance chicken camouflaged in the northern deciduous highlands.",
    ["OOX-17/TN Mech-Chicken"] = "Gnomish homing beacon automaton broadcasting distressed distress frequencies across the desert.",
    ["OOX-22/FE Mech-Chicken"] = "Dense jungle exploratory mech equipped with advanced dampening gyroscopes.",
    ["Ol' Sooty"] = "Soot-covered mountain bear inhabiting iron mines and granite crags above Thelsamar.",
    ["Old Cliff Jumper"] = "Wily cliff wolf leaping effortlessly across the mountain plateaus of the Hinterlands.",
    ["Olm the Wise"] = "Ancient white spirit owl radiating mystical arcane feathers and prophetic wisdom.",
    ["Ornery Plainstrider"] = "Belligerent tallstrider with razor beak and a habit of kicking safari hunters in the chest.",
    ["Plaguebat Matron"] = "Colossal carrier bat dripping with active plague spores that sicken nearby wildlife.",
    ["Plagued Swine"] = "Diseased zombie boar roaming the Corin's Crossing fungal patches, immune to pain.",
    ["Polar Bear"] = "Arctic apex predators insulated by dense sub-zero fur and fat, thriving in glacial blizzards.",
    ["Prairie Wolf"] = "Swift golden-coated hunters stalking the grassy savannahs of Central Kalimdor.",
    ["Princess"] = "Prize-winning colossal swine of the Brackwell Pumpkin Patch, renowned for gourmand appetites.",
    ["Pygmy Surf Crawler"] = "Fast-scuttling coastal crab pinching unwary swimmers with razor pincers.",
    ["Rabid Bear"] = "Blight-infected bear whose fur has peeled away to expose rotting, disease-infused muscles.",
    ["Rabid Blighthound"] = "Diseased hound afflicted with mindless necrotic frenzy, lashing out at any living warmth.",
    ["Razormaw"] = "Crimson swamp raptor with jagged serrated fangs capable of crushing dragon bones.",
    ["Razzashi Serpent"] = "Emerald-winged jungle serpent striking with venomous spitting darts.",
    ["Razzashi Swine"] = "Tropical wild boar bred for aggressive territorial defense, adorned with venomous jungle spines.",
    ["Red Whelpling"] = "Young broodling of the Red Dragonflight, breathing nascent flames to defend dragonkin roosts.",
    ["Ressan the Needler"] = "White spectral bat terrorizing the ruined mills of northern Tirisfal with razor-sharp needle fangs.",
    ["River Crocolisk"] = "Armor-scaled amphibious predators lurking submerged near riverbanks before clamping shut.",
    ["Rock Rumbler"] = "Craggy earth elemental capable of triggering localized tremors with each heavy step.",
    ["Rotgrip"] = "Monstrous subterranean crocolisk boss guarding the foul waters of Princess Theradras's domain.",
    ["Rotted Horror"] = "Decaying monstrosity stitched together from graveyard scraps, radiating grave chill.",
    ["Rotting Behemoth"] = "Plague-bloated ancient alligator decomposing in murky bog waters.",
    ["Rotting Hog"] = "Undead hog spreading noxious fumes and necrotic rot across ruined Lordaeron farms.",
    ["Saltwater Crocolisk"] = "Massive marine crocolisk basking in tropical sun along southern island reefs.",
    ["Sand Vortex"] = "Towering dust storm entity scouring the desert ruins with abrasive sand blasts.",
    ["Savannah Hyena"] = "Vicious pack scavengers with bone-crushing jaws and a demoralizing, psychotic cackle.",
    ["Savannah Prowler"] = "Pride hunters of the sun-drenched savannahs, coordinating swift strikes against stampeding herds.",
    ["Scorched Boar"] = "Heat-hardened boar with cinder-dusted hide, thriving along molten volcanic cracks.",
    ["Scorpashi Lasher"] = "Savage desert scorpid with dual whip stingers adapted for rocky canyons.",
    ["Scorpid Worker"] = "Desert arachnid armored in chitin plates, striking with a curved tail dripping with acid venom.",
    ["Scrap Reaver"] = "Junk-assembled reaper cobbled together by Goblin scavengers from crashed flying machines.",
    ["Sea Sprite"] = "Gentle coastal water elemental singing with the rhythmic ebb and flow of tidal surf.",
    ["Sewer Beast"] = "Mythical albino crocolisk lurking within the dark subterranean waterways beneath Stormwind City.",
    ["Shadow Panther"] = "Midnight-coated stealth hunter slipping invisibly through the murky bogs and mangrove trees.",
    ["Shadra's Brood"] = "Direct spawn of the venom loa Shadra, dripping with lethal divine poison.",
    ["Shanda the Spinner"] = "Ancient silver web-weaver stalking the damp caves of Loch Modan with paralyzing toxins.",
    ["Shardtooth Bear"] = "Massive glacial bear with teeth hard as diamond crystals, hunting in deep winter drifts.",
    ["Shy-Rotam"] = "Beloved mate of Sian-Rotam, defending the frosty high mountain plateau with maternal ferocity.",
    ["Sian-Rotam"] = "The sacred white frost lion of Winterspring summoned at the Rock of Shy-Rotam.",
    ["Silithid Swarmer"] = "Hive-mind insect soldier serving the insectoid empire beneath Kalimdor's crust.",
    ["Sin'Dall"] = "Cunning matriarch tigress roaming the cliffs near Nesingwary's expedition camp.",
    ["Skeletal Flayer"] = "Animated skeletal hound prowling the desecrated burial grounds of Lordaeron nobility.",
    ["Skeletal Raptor"] = "Fossilized raptor reanimated by necromancers, hunting with cold, unliving ferocity.",
    ["Skeletal Steed"] = "Undead stallion ridden by the Forsaken deathguard, possessing unending stamina and icy hooves.",
    ["Slavering Worg"] = "Massive, muscle-bound canine corrupted by shadow and lunar curses, possessing terrifying jaw strength.",
    ["Snapjaw Turtle"] = "Ancient shelled reptile with an unbreakable defensive carapace and snapping beak.",
    ["Snarler"] = "Legendary dark wolf of Feralas blessed with innate elemental resistances to all magic schools.",
    ["Snarlmane"] = "Cursed ghost worg bound to Arugal's keep, rending mortal flesh with anti-healing necrotic bites.",
    ["Snickerfang Hyena"] = "Fierce desert hyena roaming the baking salt dunes, harassing travelers with manic laughter.",
    ["Sparking Gale"] = "Furious thundercloud elemental summoned during Burning Blade demonic rituals.",
    ["Sparkleshell Snapper"] = "Crystal-shelled turtle reflecting the blinding desert sun of the salt flats.",
    ["Spectral Saber"] = "Ghostly nightsaber roaming ancient ruins, flickering between the corporeal world and the Shadowlands.",
    ["Spectral Watcher"] = "Ghostly guardian bound to patrol the eerie winds swirling around the tower of Karazhan.",
    ["Spiteflayer"] = "Corrupted nether vulture feeding on demonic remnants around the Dark Portal.",
    ["Sprite Darter"] = "Elusive faerie dragon fluttering with iridescent wings, immune to hostile spellcraft.",
    ["Stone Golem"] = "Heavy granite sentry guarding Titan excavations from Dark Iron dwarf sappers.",
    ["Stormsnout"] = "Aggressive saurian that snorts ozone and sparks when cornered by safari hunters.",
    ["Stranglethorn Raptor"] = "Vibrant blue and green hunter patrolling the ruined troll temples along the coast.",
    ["Stranglethorn Tiger"] = "Monstrous striped cats camouflaged within the dense tropical foliage of the southern jungles.",
    ["Strashaz Hydromancer Crab"] = "Naga-trained war crustacean capable of generating pressurized water shields.",
    ["Strigid Owl"] = "Silent nocturnal fliers striking from tree canopies with talons sharp as steel daggers.",
    ["Sunscale Scytheclaw"] = "Crimson and gold raptor blessed with tough heat-resistant scales.",
    ["Takk the Leaper"] = "Legendary turquoise raptor celebrated for soaring leaps and unbeatable land speed.",
    ["Tar Lord"] = "The gargantuan titan-sludge monarch dominating the central bubbling tar basin.",
    ["Tar Lurker"] = "Viscous primordial slime entity suffocating foes in thick bubbling black pitch.",
    ["Tempest Sprite"] = "Lightning-sparking storm elemental conjured by ancient marsh hags.",
    ["Tethis"] = "The cunning alpha raptor hunted by Nesingwary's elite safari marksmen throughout the southern jungle.",
    ["The Rake"] = "Young, ferocious golden mountain cat prowling the cliffs of Mulgore with unmatched agility.",
    ["Thistle Bear"] = "Afflicted dark bear suffering from demonic madness, easily enraged by intruders.",
    ["Thunder Lizard"] = "Ancient Kalimdor saurian that channels raw lightning surges along its dorsal spine.",
    ["Thunderhead"] = "Legendary apex blue thunder lizard roaming the southern Barrens, crackling with storm energy.",
    ["Tidal Surge"] = "Massive ocean surge spirit crashing against sunken piers and stormwalls.",
    ["Timber"] = "White snow wolf wandering the jagged slopes of Ironforge mountain, elusive and fast.",
    ["Timber Wolf"] = "Fierce pack predators roaming temperate woodlands, striking with coordinated precision.",
    ["Tsul'Kalu"] = "Legendary white gorilla hunted as one of Nesingwary's greatest safari trophies.",
    ["Un'Goro Ravager"] = "Colossal prehistoric raptor terrorizing the primordial basin with raw savagery.",
    ["Unholy Scourgehound"] = "Massive two-headed hellhound bred in the slaughterhouses of Baron Rivendare.",
    ["Ursangous"] = "Furious brown bear corrupted by demon blood spilling across Ashenvale's sacred groves.",
    ["Ursius"] = "Ancient frost-crowned behemoth bear commanding the highest peaks of Mount Hyjal foothills.",
    ["Vampiric Bat"] = "Blood-starved cave bat infected with dark necromantic magic.",
    ["Vengeful Shade"] = "Tormented highborne spirit trapped in the ruins of ancient Kalimdor, weeping shadowy tears.",
    ["Vicious Gray Bear"] = "Gray-pelted territorial predator that fiercely guards woodland honey trees and river crossings.",
    ["Vile Sting"] = "Lethal apex scorpid patrolling the wind-carved stone pillars of Thousand Needles.",
    ["Volatile Micro-Bot"] = "Tiny self-destructing robot engineered to overload its battery cells when damaged.",
    ["War Golem"] = "Massive Dark Iron steam-powered juggernaut forged to shatter battlements and crush intruders.",
    ["Washte Pawne"] = "Legendary feathered serpent revered by the Tauren as the Spirit of the High Plains.",
    ["Wind Serpent"] = "Feathered serpentine fliers channeling lightning and nature bursts directly through their crests.",
    ["Witherbark Raptor"] = "Bred by Witherbark trolls to ambush high elf lodges in the northern forests.",
    ["Wood Lurker"] = "Arboreal spider dropping from pine branches onto unsuspecting travelers.",
    ["Zaricotl"] = "Immense flaming roc soaring above the scorched valleys of the Badlands.",
    ["Zephyr Sylph"] = "Graceful desert wind spirit dancing across sand dunes with gale-force agility.",
}

Bestiary.SPECIES = {}
Bestiary.LookupById = {}
Bestiary.LookupByName = {}
Bestiary.LookupByNpcId = {}

-- =========================================================================
-- 🛠 DYNAMIC CATALOG GENERATION FROM CREATUREDB
-- =========================================================================
function Bestiary:BuildFromCreatureDB()
    local creatureDB = FS.CreatureDB
    if not creatureDB then return end

    wipe(self.SPECIES)
    wipe(self.LookupById)
    wipe(self.LookupByName)
    wipe(self.LookupByNpcId)

    local zoneRegistry = FS.ZoneRegistry or {}
    local itemDB = FS.ItemDB or {}
    local familyDiets = itemDB.FAMILY_DIETS or {}

    -- 1. Aggregate unique species by creature name
    local speciesMap = {}
    local speciesOrder = {}

    for npcId, entry in pairs(creatureDB) do
        local name = entry.name
        if name and name ~= "" then
            local sp = speciesMap[name]
            if not sp then
                sp = {
                    name = name,
                    family = entry.family or "Beast",
                    subFamily = entry.subFamily or entry.family or "Beast",
                    spec = entry.spec or "Ferocity",
                    element = entry.element or "Beast",
                    displayId = entry.displayId or 0,
                    primaryNpcId = npcId,
                    minLevel = entry.minLevel or 1,
                    maxLevel = entry.maxLevel or entry.minLevel or 1,
                    classification = entry.classification or 0,
                    isBoss = (entry.isBoss == true) or (entry.classification == 3),
                    isApexRare = (entry.isRare == true) or (entry.isRareSpawn == true) or (entry.classification == 2),
                    moves = entry.moves or entry.abilities or { 101, 102 },
                    baseStats = entry.baseStats or { hp = 30, atk = 25, def = 25, spd = 20 },
                    npcIds = { npcId },
                    zoneSet = {},
                }
                speciesMap[name] = sp
                table.insert(speciesOrder, sp)
            else
                table.insert(sp.npcIds, npcId)
                if entry.minLevel and entry.minLevel < sp.minLevel then
                    sp.minLevel = entry.minLevel
                end
                if entry.maxLevel and entry.maxLevel > sp.maxLevel then
                    sp.maxLevel = entry.maxLevel
                end
                if (sp.displayId == 0 or not sp.displayId) and entry.displayId and entry.displayId > 0 then
                    sp.displayId = entry.displayId
                    sp.primaryNpcId = npcId
                end
                if (entry.isBoss == true) or (entry.classification == 3) then
                    sp.isBoss = true
                end
                if (entry.isRare == true) or (entry.isRareSpawn == true) or (entry.classification == 2) then
                    sp.isApexRare = true
                end
                if entry.classification and entry.classification > sp.classification then
                    sp.classification = entry.classification
                end
                if entry.moves and #entry.moves > #sp.moves then
                    sp.moves = entry.moves
                end
            end

            -- Map zone IDs
            if entry.zones then
                for _, zid in ipairs(entry.zones) do
                    sp.zoneSet[zid] = true
                end
            end
        end
    end

    -- 2. Sort species deterministically: Family -> SubFamily -> Name
    table.sort(speciesOrder, function(a, b)
        local famA = a.family or ""
        local famB = b.family or ""
        if famA ~= famB then return famA < famB end
        local subA = a.subFamily or ""
        local subB = b.subFamily or ""
        if subA ~= subB then return subA < subB end
        return a.name < b.name
    end)

    -- 3. Finalize bestiary species roster with metadata and sequential IDs
    for idx, sp in ipairs(speciesOrder) do
        sp.id = idx
        sp.movepool = sp.moves

        -- Resolve human-readable habitats
        local habitats = {}
        for zid in pairs(sp.zoneSet) do
            local zInfo = zoneRegistry[zid]
            local zName = zInfo and zInfo.name
            if zName and zName ~= "" and zName ~= "Azeroth" and zName ~= "Eastern Kingdoms" and zName ~= "Kalimdor" then
                table.insert(habitats, zName)
            end
        end
        table.sort(habitats)
        if #habitats == 0 then
            table.insert(habitats, "Wilds of Azeroth")
        end
        sp.habitats = habitats

        -- Resolve Rarity badge
        if sp.isBoss then
            sp.rarity = "World Boss"
        elseif sp.isApexRare then
            sp.rarity = "Rare Apex"
        elseif sp.classification == 1 then
            sp.rarity = "Elite"
        else
            sp.rarity = "Common"
        end

        -- Resolve Sustenance Diet
        local dietData = familyDiets[sp.subFamily] or familyDiets[sp.family]
        if dietData and dietData.favorite then
            local favClean = string.gsub(dietData.favorite, "food_", "")
            favClean = string.upper(string.sub(favClean, 1, 1)) .. string.sub(favClean, 2)
            sp.diet = "Fresh " .. favClean .. " (+25 Attunement)"
        else
            sp.diet = "Fresh Meat / Sustenance (+25 Attunement)"
        end

        -- Resolve Field Lore / Description
        local customLore = self.LORE[sp.name]
        if customLore and customLore ~= "" then
            sp.description = customLore
        else
            local primaryZone = habitats[1] or "Azeroth"
            sp.description = string.format("Native to %s. A %s member of the %s family exhibiting %s temperament with %s elemental affinity.",
                primaryZone, sp.rarity, sp.subFamily, sp.spec, sp.element)
        end

        -- Register in master collections and fast lookups
        self.SPECIES[idx] = sp
        self.LookupById[idx] = sp
        self.LookupByName[string.lower(sp.name)] = sp
        if sp.primaryNpcId then
            self.LookupByNpcId[sp.primaryNpcId] = sp
        end
        for _, npcId in ipairs(sp.npcIds) do
            self.LookupByNpcId[npcId] = sp
        end
    end
end

-- Fast public query APIs
function Bestiary:GetSpecies(idOrName)
    if not idOrName then return nil end
    if type(idOrName) == "number" then
        return self.LookupById[idOrName] or self.LookupByNpcId[idOrName]
    elseif type(idOrName) == "string" then
        return self.LookupByName[string.lower(idOrName)]
    end
    return nil
end

function Bestiary:FindSpeciesByName(name)
    if not name then return nil end
    return self.LookupByName[string.lower(name)]
end

function Bestiary:GetSpeciesByNpcId(npcId)
    if not npcId then return nil end
    return self.LookupByNpcId[npcId]
end

function Bestiary:GetAllSpecies()
    return self.SPECIES
end

function Bestiary:GetTotalCount()
    return #self.SPECIES
end

-- Build master species catalog immediately at file load
Bestiary:BuildFromCreatureDB()
