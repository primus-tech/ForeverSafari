#!/usr/bin/env python3
import json
import re
import os

STEPS_DIR = "/home/primustech/.gemini/antigravity-ide/brain/40abe491-18a6-4c46-aebf-9a1bf9235bef/.system_generated/steps"
OUTPUT_DIR = "/home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/Creatures"
BEASTS_DIR = os.path.join(OUTPUT_DIR, "Beasts")

def load_step_file(step_num):
    filepath = os.path.join(STEPS_DIR, str(step_num), "content.md")
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Step {step_num} content not found at {filepath}")
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()

def parse_listview_data(html_text):
    decoder = json.JSONDecoder()
    idx = html_text.find('"data":[')
    if idx != -1:
        idx += len('"data":')
        data, _ = decoder.raw_decode(html_text, idx)
        return data
    return []

# -------------------------------------------------------------
# 1. ZONE EXTRACTION & CLASSIFICATION
# -------------------------------------------------------------
print("--> Parsing Zone definitions...")

# Extract from filter form options in dragonkin step 2534
dragonkin_html = load_step_file(2534)
m = re.search(r'Filter\.init\((\{.*?\})\);', dragonkin_html, re.DOTALL)
filter_zones = {}
if m:
    obj = json.loads(m.group(1))
    for f in obj.get('filters', []):
        if f.get('term') == 'foundin_ellipsis':
            cur_group = None
            for opt in f.get('options', []):
                val, label = opt[0], opt[1]
                if val is None:
                    cur_group = label
                else:
                    filter_zones[val] = (label, cur_group)

# Zone step mappings
zone_steps = {
    'dungeon': 2530,
    'raid': 2550,
    'world_1_20': 2552,
    'world_21_40': 2554,
    'world_41_60': 2556,
}

# 1. Collect all known instance IDs first
known_instance_ids = set()
for step_num in [2530, 2550]: # Dungeons & Raids
    for z in parse_listview_data(load_step_file(step_num)):
        known_instance_ids.add(z.get('id'))

for zid, (zname, group) in filter_zones.items():
    if group in ('Battlegrounds', 'Dungeons', 'Raids') or zid == 2159: # Onyxia's Lair
        known_instance_ids.add(zid)

zone_registry = {} # zid -> { id, name, type, isInstance }

# Load from step files, respecting known_instance_ids
for ztype, step_num in zone_steps.items():
    html = load_step_file(step_num)
    data = parse_listview_data(html)
    for z in data:
        zid = z.get('id')
        name = z.get('name')
        is_inst = zid in known_instance_ids
        actual_type = ('raid' if ztype == 'raid' or zid in (2159, 2717, 2677, 3456, 3428, 3429, 1977)
                       else ('dungeon' if (ztype == 'dungeon' or is_inst) else ztype))
        zone_registry[zid] = {
            'id': zid,
            'name': name,
            'type': actual_type,
            'isInstance': is_inst,
            'minLevel': z.get('minlevel', 0),
            'maxLevel': z.get('maxlevel', 0)
        }

# Augment from Wowhead filter dropdown
for zid, (zname, group) in filter_zones.items():
    is_inst = zid in known_instance_ids
    if zid not in zone_registry:
        gtype = 'battleground' if group == 'Battlegrounds' else ('dungeon' if group == 'Dungeons' else ('raid' if (group == 'Raids' or zid == 2159) else 'open_world'))
        zone_registry[zid] = {
            'id': zid,
            'name': zname,
            'type': gtype,
            'isInstance': is_inst,
            'minLevel': 0,
            'maxLevel': 0
        }
    elif is_inst:
        zone_registry[zid]['isInstance'] = True

instance_zone_ids = {zid for zid, z in zone_registry.items() if z['isInstance']}
world_zone_ids = {zid for zid, z in zone_registry.items() if not z['isInstance']}

print(f"Master Zones: {len(zone_registry)} total ({len(instance_zone_ids)} instances/raids/bgs, {len(world_zone_ids)} open world)")

# -------------------------------------------------------------
# 2. BEAST SUBFAMILIES & HUNTER PET ARCHETYPES
# -------------------------------------------------------------
beast_subcats = {
    'Bat': (2576, 'Cunning', 'Beast', 101, 118, 'Bat Pup'),
    'Bear': (2588, 'Tenacity', 'Beast', 110, 112, 'Bear Cub'),
    'Bird of Prey': (2590, 'Cunning', 'Beast', 101, 118, 'Fledgling'),
    'Boar': (2592, 'Tenacity', 'Beast', 111, 112, 'Boar Piglet'),
    'Carrion Bird': (2594, 'Ferocity', 'Beast', 103, 118, 'Hatchling'),
    'Cat': (2596, 'Ferocity', 'Beast', 103, 118, 'Kitten'),
    'Crab': (2598, 'Tenacity', 'Aquatic', 101, 404, 'Crab Pinchling'),
    'Crocolisk': (2600, 'Tenacity', 'Aquatic', 101, 112, 'Baby Crocolisk'),
    'Gorilla': (2602, 'Tenacity', 'Beast', 101, 904, 'Baby Gorilla'),
    'Hyena': (2604, 'Ferocity', 'Beast', 101, 118, 'Hyena Pup'),
    'Raptor': (2606, 'Ferocity', 'Beast', 115, 118, 'Raptor Hatchling'),
    'Scorpid': (2608, 'Tenacity', 'Beast', 101, 904, 'Scorpid Scuttler'),
    'Spider': (2610, 'Cunning', 'Shadow', 101, 118, 'Spiderling'),
    'Tallstrider': (2612, 'Ferocity', 'Beast', 101, 118, 'Tallstrider Chick'),
    'Turtle': (2614, 'Tenacity', 'Aquatic', 101, 404, 'Turtle Hatchling'),
    'Wind Serpent': (2616, 'Ferocity', 'Nature', 101, 118, 'Spiteful Whelpling'),
    'Wolf': (2622, 'Ferocity', 'Beast', 101, 118, 'Wolf Pup'),
}

# -------------------------------------------------------------
# 2B. RETAIL WOWHEAD CLASSIFICATION MASK & SUBFAMILY SPECS
# -------------------------------------------------------------
SUBFAMILY_SPECS = {
    'Aquatic': ('Ferocity', 'Aquatic', 101, 406, 'Minnow'),
    'Basilisk': ('Tenacity', 'Earth', 101, 112, 'Baby Basilisk'),
    'Bat': ('Cunning', 'Beast', 101, 118, 'Bat Pup'),
    'Bear': ('Tenacity', 'Beast', 110, 112, 'Bear Cub'),
    'Bird of Prey': ('Cunning', 'Beast', 101, 118, 'Fledgling'),
    'Boar': ('Tenacity', 'Beast', 111, 112, 'Boar Piglet'),
    'Carrion Bird': ('Ferocity', 'Beast', 103, 118, 'Hatchling'),
    'Cat': ('Ferocity', 'Beast', 103, 118, 'Kitten'),
    'Chimaera': ('Ferocity', 'Nature', 101, 118, 'Chimaera Hatchling'),
    'Core Hound': ('Ferocity', 'Fire', 101, 118, 'Core Hound Pup'),
    'Crab': ('Tenacity', 'Aquatic', 101, 404, 'Crab Pinchling'),
    'Crocolisk': ('Tenacity', 'Aquatic', 101, 112, 'Baby Crocolisk'),
    'Devilsaur': ('Ferocity', 'Beast', 101, 118, 'Devilsaur Hatchling'),
    'Dinosaur': ('Tenacity', 'Beast', 114, 112, 'Dino Hatchling'),
    'Fox': ('Cunning', 'Beast', 101, 118, 'Fox Kit'),
    'Gorilla': ('Tenacity', 'Beast', 101, 904, 'Baby Gorilla'),
    'Hydra': ('Ferocity', 'Aquatic', 101, 118, 'Hydra Hatchling'),
    'Hyena': ('Ferocity', 'Beast', 101, 118, 'Hyena Pup'),
    'Kodo': ('Tenacity', 'Earth', 114, 112, 'Kodo Calf'),
    'Raptor': ('Ferocity', 'Beast', 115, 118, 'Raptor Hatchling'),
    'Scorpid': ('Tenacity', 'Beast', 101, 904, 'Scorpid Scuttler'),
    'Serpent': ('Cunning', 'Nature', 101, 118, 'Serpent Whelp'),
    'Silithid': ('Cunning', 'Nature', 101, 118, 'Silithid Grub'),
    'Spider': ('Cunning', 'Shadow', 101, 118, 'Spiderling'),
    'Stag': ('Cunning', 'Beast', 101, 118, 'Fawn'),
    'Tallstrider': ('Ferocity', 'Beast', 101, 118, 'Tallstrider Chick'),
    'Turtle': ('Tenacity', 'Aquatic', 101, 404, 'Turtle Hatchling'),
    'Wind Serpent': ('Ferocity', 'Nature', 101, 118, 'Spiteful Whelpling'),
    'Wolf': ('Ferocity', 'Beast', 101, 118, 'Wolf Pup'),
    'Worm': ('Tenacity', 'Nature', 101, 404, 'Worm Larva'),
}

retail_mask_file = os.path.join(os.path.dirname(__file__), 'retail_pet_mask.json')
retail_mask = {}
if os.path.exists(retail_mask_file):
    with open(retail_mask_file, 'r', encoding='utf-8') as f:
        retail_mask = json.load(f)
print(f'Loaded Retail Classification Mask: {len(retail_mask)} authoritative entries.')

def get_beast_classification(mob):
    mid_str = str(mob.get('id'))
    if mid_str in retail_mask:
        subf = retail_mask[mid_str]['subFamily']
        if subf in SUBFAMILY_SPECS:
            spec, elem, m1, m2, pup = SUBFAMILY_SPECS[subf]
            return subf, spec, elem, m1, m2, pup
    return detect_beast_subfamily(mob.get('name', ''))

def detect_beast_subfamily(name):
    nl = name.lower()
    if any(k in nl for k in ['core rager', 'core hound', 'corehound', 'magma hound', 'the beast', 'kurken', 'magmadar', 'calefactus']):
        return 'Core Hound', 'Ferocity', 'Fire', 101, 118, 'Core Hound Pup'
    if any(k in nl for k in ['devilsaur', 'tyrantus', 'mosh', 'titanzilla']):
        return 'Devilsaur', 'Ferocity', 'Beast', 101, 118, 'Devilsaur Hatchling'
    if any(k in nl for k in ['stegodon', 'diemetradon', 'incendosaur']):
        return 'Dinosaur', 'Tenacity', 'Beast', 114, 112, 'Dino Hatchling'
    if any(k in nl for k in ['chimaera', 'chimaerok', 'lakmaeran', 'chillwind ravager']):
        return 'Chimaera', 'Ferocity', 'Nature', 101, 118, 'Chimaera Hatchling'
    if any(k in nl for k in ['scarab', 'skitterer', 'maexxna', 'spider', 'tarantula', 'widow', 'spinner', 'creeper', 'smolderweb', 'shadra', 'mar\'li', 'nandieb', 'harvester swarm', 'hedrum', 'fang', 'web', 'lurker', 'recluse', 'valraxx', 'sathrah', 'besseleth', 'sri\'skulk', 'broodguard', 'broodmother', 'chatter', 'naraxis', 'creepthess', 'krek the noxious', 'ta\'shkal', 'shadow', 'nightshade']):
        return 'Spider', 'Cunning', 'Shadow', 101, 118, 'Spiderling'
    if any(k in nl for k in ['silithid', 'wasp', 'cirrusfly', 'fly', 'grub', 'borer', 'centipa', 'parasite', 'larva', 'maggot', 'corpsefeeder', 'swarmer', 'sul\'lithuz', 'needler', 'githyiss', 'blood flies', 'sandfury guardian']):
        return 'Silithid', 'Cunning', 'Nature', 101, 118, 'Silithid Grub'
    if any(k in nl for k in ['kodo', 'clefthoof', 'thunder lizard', 'lightning hide', 'stormhide', 'thunderhead', 'brontus', 'lakota', 'arra', 'dadanga', 'owatanka', 'thunderstomp']):
        return 'Kodo', 'Tenacity', 'Earth', 114, 112, 'Kodo Calf'
    if any(k in nl for k in ['basilisk', 'lizard', 'salamander', 'saltspine', 'skum', 'crystal spine', 'gritjaw', 'gazer', 'crystalhide', 'petrifier', 'mirrorscale', 'deatheye', 'ambereye reaver']):
        return 'Basilisk', 'Tenacity', 'Earth', 101, 112, 'Baby Basilisk'
    if any(k in nl for k in ['hydra', 'gesharahan']):
        return 'Hydra', 'Ferocity', 'Aquatic', 101, 118, 'Hydra Hatchling'
    if any(k in nl for k in ['crocolisk', 'croc', 'alligator', 'gator', 'rotgrip', 'scale belly', 'chomper', 'needletooth', 'deviate lurker', 'deviate horror', 'daggermaw', 'vicejaw', 'sewer beast', 'deadmire', 'ripscale', 'gnashjaw']):
        return 'Crocolisk', 'Tenacity', 'Aquatic', 101, 112, 'Baby Crocolisk'
    if any(k in nl for k in ['turtle', 'snapjaw', 'tortoise', 'gammerita', 'torta', 'ghamoo-ra', 'gamma-ra', 'ghamoo-raja', 'tooga', 'speedy', 'kresh', 'ironback', 'tortolla', 'sawtooth', 'steeljaw']):
        return 'Turtle', 'Tenacity', 'Aquatic', 101, 404, 'Turtle Hatchling'
    if any(k in nl for k in ['crab', 'crawler', 'pincer', 'crawfish', 'crustacean', 'makrura', 'deathclasp', 'surf glider', 'spikeshell', 'burrower', 'clack the reaver']):
        return 'Crab', 'Tenacity', 'Aquatic', 101, 404, 'Crab Pinchling'
    if any(k in nl for k in ['gorilla', 'ape', 'groddok', 'mukla', 'knuckles', 'mokk the savage', 'silverback', 'kurmokk', 'u\'cha', 'uhk\'loc', 'stomper', 'thunderer']):
        return 'Gorilla', 'Tenacity', 'Beast', 101, 904, 'Baby Gorilla'
    if any(k in nl for k in ['raptor', 'scytheclaw', 'razormaw', 'prideclaw', 'ravasaur', 'riptooth', 'lar\'korwi', 'lashtail', 'taillasher', 'scythemaw', 'sarltooth', 'dart', 'tethis']):
        return 'Raptor', 'Ferocity', 'Beast', 115, 118, 'Raptor Hatchling'
    if any(k in nl for k in ['wyvern', 'manticore', 'wind serpent', 'couatl', 'pridewing', 'highperch', 'hakkar', 'arikara', 'venomwing', 'coiler', 'stinglash']):
        return 'Wind Serpent', 'Ferocity', 'Nature', 101, 118, 'Spiteful Whelpling'
    if any(k in nl for k in ['bat', 'duskbat', 'vampiric']):
        return 'Bat', 'Cunning', 'Beast', 101, 118, 'Bat Pup'
    if any(k in nl for k in ['bear', 'urs', 'grizzly', 'polar', 'black bear', 'ironfur', 'rabid thistle bear', 'ursol\'lok', 'grimclaw', 'stonepaw', 'bruuz', 'thornpaw', 'protector', 'ironclaw', 'bjarn', 'ol\' sooty', 'den mother', 'mangeclaw', 'samras', 'thistle cub', 'shardtooth', 'angerclaw', 'grizzlegut', 'barnabus', 'elmpaw', 'bristlefur', 'sootfur']):
        return 'Bear', 'Tenacity', 'Beast', 110, 112, 'Bear Cub'
    if any(k in nl for k in ['cat', 'lion', 'tiger', 'panther', 'cougar', 'lynx', 'sabercat', 'saber', 'stalker', 'leopard', 'shadumbra', 'saeyleenan', 'eskhandar', 'bigglesworth', 'kitten', 'zulian guardian', 'roary', 'defias companion', 'antilos', 'shadetooth', 'savannah', 'the rake', 'humar', 'sin\'dall', 'bhag\'thera', 'king bangalash', 'broken tooth', 'shadowclaw', 'dishu', 'shy-rotam', 'sian-rotam', 'stranglethorn tigress', 'rak\'shiri', 'swamp jaguar', 'ridge huntress', 'zulian cub', 'mystmane', 'highmane', 'dakotah', 'katrixa', 'luna', 'selene', 'aedamas', 'dendarro', 'shok\'tara']):
        return 'Cat', 'Ferocity', 'Beast', 103, 118, 'Kitten'
    if any(k in nl for k in ['fox', 'remi', 'inariel']):
        return 'Fox', 'Cunning', 'Beast', 101, 118, 'Fox Kit'
    if any(k in nl for k in ['wolf', 'worg', 'howl', 'prowler', 'bloodhound', 'lupine', 'fenrus', 'blighthound', 'hound', 'mastiff', 'darkhound', 'doomhound', 'deathhound', 'halycon', 'gizrul', 'borelgore', 'woof', 'pupper', 'goldrinn', 'kyle', 'snort', 'shadowhound', 'glenrunner', 'mistrunner', 'coyote', 'lupos', 'steelsnap', 'bonepaw', 'timber', 'snarler', 'deathmaw', 'longtooth', 'spot', 'winterax tracker', 'nahr\'ek', 'kamuro', 'kuroma', 'rippa', 'halikor', 'stormheart', 'ryff']):
        return 'Wolf', 'Ferocity', 'Beast', 101, 118, 'Wolf Pup'
    if any(k in nl for k in ['boar', 'swine', 'pig', 'tusk', 'snout', 'agathelos', 'agamaggan', 'margol', 'princess', 'agam\'ar', 'porcine', 'grunter']):
        return 'Boar', 'Tenacity', 'Beast', 111, 112, 'Boar Piglet'
    if any(k in nl for k in ['hyena', 'scavenger', 'blisterpaw', 'giggler', 'grinning dog']):
        return 'Hyena', 'Ferocity', 'Beast', 101, 118, 'Hyena Pup'
    if any(k in nl for k in ['bird', 'owl', 'hawk', 'eagle', 'falcon', 'sharptalon', 'fledgling', 'hippogryph', 'gryphon', 'pterrordax', 'skylord', 'cloudrunner', 'freewind', 'razorbeak', 'mistwing', 'sharpbeak', 'razza', 'duskwing', 'dawnchaser', 'buzzbeak', 'snapbeak', 'swiftwind', 'keenclaw', 'antilus', 'soarer', 'heartrazor', 'ironeye', 'sorrow wing', 'evalcharr', 'whisperwing', 'parrot', 'crow', 'frayfeather', 'polly', 'pollo', 'plymouth rock', 'swoop', 'screecher', 'screamer', 'strigid', 'ironbeak', 'roc', 'azzere', 'zaricotl', 'spiteflayer', 'olm the wise', 'shrieker', 'shriekling', 'fernfeather', 'vulgara', 'pterodan', 'sky shadow', 'bassbeak', 'arcterris']):
        return 'Bird of Prey', 'Cunning', 'Beast', 101, 118, 'Fledgling'
    if any(k in nl for k in ['vulture', 'buzzard', 'condor', 'carrion', 'ripper', 'fleshripper', 'bonepicker', 'vultros', 'zopilote', 'soulflayer', 'corpsefeeder']):
        return 'Carrion Bird', 'Ferocity', 'Beast', 103, 118, 'Hatchling'
    if any(k in nl for k in ['tallstrider', 'strider', 'mazzranache', 'washte pawne']):
        return 'Tallstrider', 'Ferocity', 'Beast', 101, 118, 'Tallstrider Chick'
    if any(k in nl for k in ['scorpid', 'scorpion', 'spire scorpid', 'sarkoth', 'scorpok', 'vile sting', 'flayer', 'shredder', 'scorpashi']):
        return 'Scorpid', 'Tenacity', 'Beast', 101, 904, 'Scorpid Scuttler'
    if any(k in nl for k in ['viper', 'python', 'adder', 'serpent', 'snake', 'hissperak', 'moccasin', 'cobra', 'slitherer', 'spitter', 'nessy']):
        return 'Serpent', 'Cunning', 'Nature', 101, 118, 'Serpent Whelp'
    if any(k in nl for k in ['stag', 'gazelle', 'deer', 'elk', 'reindeer', 'courser', 'zhevra', 'giraffe', 'ram', 'buck', 'branch-horn', 'mosshoof', 'cliff stormer', 'swiftmane', 'alterac ram', 'khaz modan ram', 'bock', 'squallclimber', 'glacier', 'brumeran']):
        return 'Stag', 'Cunning', 'Beast', 101, 118, 'Fawn'
    if any(k in nl for k in ['shark', 'threshadon', 'frenzy', 'fish', 'serra\'kis', 'isha', 'muck frenzy', 'thresher', 'threshfin', 'minnow', 'orca', 'piranha', 'blightsculler']):
        return 'Aquatic', 'Ferocity', 'Aquatic', 101, 406, 'Minnow'
    if any(k in nl for k in ['worm', 'oozeworm', 'sandworm', 'dredge', 'silt devourer']):
        return 'Worm', 'Tenacity', 'Nature', 101, 404, 'Worm Larva'
    
    # Absolute fallback (mapped to closest family instead of Exotic)
    return 'Wolf', 'Ferocity', 'Beast', 101, 118, 'Wolf Pup'

# -------------------------------------------------------------
# 3. EXTRACTION HELPER
# -------------------------------------------------------------
master_creatures = {} # npc_id -> dict

def sanitize_name(name):
    if not name:
        return "Unknown"
    return name.replace('"', '\\"').strip()

def is_sentient_or_invalid(mob):
    name = mob.get('name', '').lower()
    tag = mob.get('tag', '') or ''
    tag_l = tag.lower()
    
    # Exclude merchants, vendors, quest givers, innkeepers, trainers
    bad_tags = ['merchant', 'trainer', 'vendor', 'quest', 'innkeeper', 'auctioneer', 'banker', 'flight master', 'stable master', 'repair']
    if any(bt in tag_l for bt in bad_tags):
        return True
        
    # Exclude player mounts, druid forms, invis trigger bunnies, internal test items
    if name == 'credit' or 'credit' in name:
        return True
    if '(druid)' in name or 'druid)' in name:
        return True
    if any(k in name for k in ['[ph]', '[dnt]', 'dummy', 'placeholder', 'test squirrel', 'secret agent', 'hunter\'s vision', 'primal blessing visual', 'human skull', 'polymorphed cockroach', 'mega rabbit', 'master angler form', 'riding druid', 'mechanical greench', 'mechanical yeti', 'mechanical squirrel', 'twain test prop', 'generic hunter pet', 'diseased experiment', 'collector of suffering', 'fallen moonkin', 'doomkin', 'abominable snowman', 'the abominable greench']):
        return True
        
    mount_words = ['riding horse', 'pinto', 'palomino', 'chestnut mare', 'brown horse', 
                   'swift palomino', 'swift white steed', 'swift brown steed', 'swift gray ram', 
                   'swift brown ram', 'swift white ram', 'argent warhorse', 'argent horse', 
                   'argent charger', 'farholde steed', 'scarlet steed', 'pack mule', 
                   'caravan mule', 'caravan packhorse', 'black war ram', 'stormpike riding ram', 
                   'white riding ram', 'risen warhorse', 'risen charger', 'silver hand charger', 
                   'darkreaver\'s fallen charger', 'black war steed', 'stabled alterac ram', 
                   'swift scarlet warhorse', 'ancient equine spirit', 'lost horse', 'fel steed',
                   'shadow charger', 'black devilsaur mount', 'warden saber mount', 'druid moose mount',
                   'horse', 'wind rider', 'war rider', 'prairie dog', 'gopher']
    if any(mw in name for mw in mount_words) or bool(re.search(r'\bmount\b', name)):
        return True
        
    # Exclude obvious humanoid guard/civilian roles in uncategorized/undead
    bad_names = ['citizen', 'peasant', 'guard', 'apprentice', 'innkeeper', 'bartender', 'lieutenant', 'captain', 'magistrate']
    if any(name.startswith(bn + ' ') or name.endswith(' ' + bn) or name == bn for bn in bad_names):
        return True
        
    return False

def calculate_stats(min_lvl, max_lvl, classification, archetype):
    lvl = max(1, (min_lvl + max_lvl) // 2) if (min_lvl and max_lvl) else 20
    is_elite = classification in (1, 2, 3)
    mult = 1.3 if is_elite else 1.0
    
    if archetype == 'Tenacity':
        return {
            'hp': int((50 + lvl * 5) * mult * 1.2),
            'atk': int((14 + lvl * 1.5) * mult),
            'def': int((16 + lvl * 2.0) * mult * 1.25),
            'spd': int((10 + lvl * 1.0) * mult * 0.9)
        }
    elif archetype == 'Ferocity':
        return {
            'hp': int((45 + lvl * 4) * mult),
            'atk': int((18 + lvl * 2.2) * mult * 1.25),
            'def': int((12 + lvl * 1.4) * mult * 0.9),
            'spd': int((14 + lvl * 1.8) * mult * 1.1)
        }
    elif archetype == 'Cunning':
        return {
            'hp': int((46 + lvl * 4.2) * mult),
            'atk': int((16 + lvl * 1.8) * mult),
            'def': int((14 + lvl * 1.6) * mult),
            'spd': int((18 + lvl * 2.2) * mult * 1.3)
        }
    else: # Magic / Spec
        return {
            'hp': int((48 + lvl * 4.5) * mult),
            'atk': int((16 + lvl * 2.0) * mult * 1.1),
            'def': int((14 + lvl * 1.6) * mult * 1.1),
            'spd': int((12 + lvl * 1.4) * mult)
        }

def process_mob(mob, family, subFamily, spec, element, move1, move2, default_pup_name):
    nid = mob.get('id')
    if not nid or nid in master_creatures:
        return
    if is_sentient_or_invalid(mob):
        return
        
    locs = mob.get('location', []) or []
    loc_set = set(locs)
    has_world = bool(loc_set & world_zone_ids)
    has_inst = bool(loc_set & instance_zone_ids)
    
    # Boss status
    boss = mob.get('boss', 0) == 1
    classif = mob.get('classification', 0)
    if classif == 3: # Boss
        boss = True
        
    # Acquisition & encounter logic
    if has_world and not has_inst:
        acq = "BATTLE"
        allow_battle = True
        allow_obs = True
        is_inst_only = False
        drop_rate = 0.0
    elif has_inst and not has_world:
        acq = "PUP_DROP"
        allow_battle = False
        allow_obs = False
        is_inst_only = True
        drop_rate = 0.25 if boss else (0.15 if classif in (1, 2) else 0.025)
    elif has_world and has_inst:
        acq = "HYBRID"
        allow_battle = True
        allow_obs = True
        is_inst_only = False
        drop_rate = 0.20 if boss else 0.03
    else: # No known loc
        # Check if known boss or patch 1.15/1.60
        if boss or classif in (1, 2, 3):
            acq = "PUP_DROP"
            allow_battle = False
            allow_obs = False
            is_inst_only = True
            drop_rate = 0.25 if boss else 0.15
        else:
            acq = "BATTLE"
            allow_battle = True
            allow_obs = True
            is_inst_only = False
            drop_rate = 0.0
            
    min_lvl = mob.get('minlevel', 1)
    max_lvl = mob.get('maxlevel', 1)
    if min_lvl > 100 or min_lvl <= 0: min_lvl = 60
    if max_lvl > 100 or max_lvl <= 0: max_lvl = 60
    
    name = sanitize_name(mob.get('name'))
    stats = calculate_stats(min_lvl, max_lvl, classif, spec)
    
    pup_name = f"{name} Pup"
    if "Hatchling" in default_pup_name:
        pup_name = f"{name} Hatchling"
    elif "Cub" in default_pup_name:
        pup_name = f"{name} Cub"
    elif "Kitten" in default_pup_name:
        pup_name = f"{name} Kitten"
    elif "Piglet" in default_pup_name:
        pup_name = f"{name} Piglet"
    elif "Fledgling" in default_pup_name:
        pup_name = f"{name} Fledgling"
    elif "Spiderling" in default_pup_name:
        pup_name = f"{name} Spiderling"
    elif "Whelp" in default_pup_name:
        pup_name = f"{name} Whelp"
    elif "Spark" in default_pup_name:
        pup_name = f"{name} Spark"
    elif "Scrap" in default_pup_name or "Micro-Bot" in default_pup_name:
        pup_name = f"{name} Micro-Bot"
    elif "Calf" in default_pup_name:
        pup_name = f"{name} Calf"
    elif "Fawn" in default_pup_name:
        pup_name = f"{name} Fawn"
    elif "Minnow" in default_pup_name:
        pup_name = f"{name} Minnow"
    
    master_creatures[nid] = {
        'id': nid,
        'name': name,
        'family': family,
        'subFamily': subFamily,
        'spec': spec,
        'element': element,
        'minLevel': min_lvl,
        'maxLevel': max_lvl,
        'classification': classif,
        'isBoss': boss,
        'zones': locs,
        'acquisition': acq,
        'allowBattle': allow_battle,
        'allowObservation': allow_obs,
        'isInstanceOnly': is_inst_only,
        'pupDropRate': drop_rate,
        'pupName': pup_name,
        'moves': [move1, move2],
        'baseStats': stats
    }

# -------------------------------------------------------------
# 4. EXECUTE EXTRACTIONS
# -------------------------------------------------------------

# A. 17 Beast Hunter Subcategories
print("--> Processing 17 Beast Subcategories...")
for family, (step_num, spec, element, m1, m2, pup_name) in beast_subcats.items():
    html = load_step_file(step_num)
    data = parse_listview_data(html)
    for mob in data:
        process_mob(mob, "Beast", family, spec, element, m1, m2, pup_name)

# B. Comprehensive Beast Level Bands (1-30, 31-50, 51-60, 61+, 0)
print("--> Processing Comprehensive Beast Level Bands (1-30, 31-50, 51-60, 61+, 0)...")
for step_num in [2859, 2863, 2867, 2869, 2871, 2558]:
    b_html = load_step_file(step_num)
    for mob in parse_listview_data(b_html):
        subf, spec, element, m1, m2, pup_name = get_beast_classification(mob)
        process_mob(mob, "Beast", subf, spec, element, m1, m2, pup_name)

# C. Dragonkin
print("--> Processing Dragonkin...")
dragon_html = load_step_file(2534)
for mob in parse_listview_data(dragon_html):
    dname = mob.get('name', '').lower()
    subf = "Faerie Dragon" if "faerie" in dname else ("Whelp" if "whelp" in dname else ("Drake" if "drake" in dname else "Dragonkin"))
    process_mob(mob, "Dragonkin", subf, "Dragonkin", "Dragonkin", 101, 806, "Whelp")

# D. Elementals
print("--> Processing Elementals...")
elem_html = load_step_file(2560)
for mob in parse_listview_data(elem_html):
    ename = mob.get('name', '').lower()
    subf = "Fire" if any(k in ename for k in ['fire', 'flame', 'magma', 'ember']) else (
           "Water" if any(k in ename for k in ['water', 'sea', 'wave', 'ice', 'frost', 'hydro']) else (
           "Earth" if any(k in ename for k in ['earth', 'rock', 'stone', 'geod', 'tar', 'mud']) else (
           "Air" if any(k in ename for k in ['air', 'wind', 'storm', 'cyclone', 'spark']) else "Elemental")))
    process_mob(mob, "Elemental", subf, "Elemental", "Elemental", 301, 307, "Elemental Spark")

# E. Mechanicals
print("--> Processing Mechanicals...")
mech_html = load_step_file(2562)
for mob in parse_listview_data(mech_html):
    mname = mob.get('name', '').lower()
    subf = "Harvest Golem" if "harvest" in mname or "golem" in mname else (
           "Alarm-o-Bot" if "alarm" in mname or "bot" in mname else (
           "Shredder" if "shredder" in mname else "Mechanical"))
    process_mob(mob, "Mechanical", subf, "Mechanical", "Mechanical", 601, 607, "Micro-Bot")

# F. Undead
print("--> Processing Undead...")
undead_html = load_step_file(2566)
for mob in parse_listview_data(undead_html):
    uname = mob.get('name', '').lower()
    subf = "Ghoul" if "ghoul" in uname else (
           "Skeleton" if any(k in uname for k in ['skelet', 'bone', 'skull']) else (
           "Plaguespider" if "spider" in uname else (
           "Ghost" if any(k in uname for k in ['ghost', 'spect', 'spirit', 'wisp', 'wraith']) else "Undead")))
    process_mob(mob, "Undead", subf, "Undead", "Shadow", 201, 204, "Bone Pup")

# G. Forever Beta Uncategorized Candidates (Applying Retail Mask)
print("--> Processing Forever Beta Uncategorized with Retail Mask...")
uncat_json_path = os.path.join(os.path.dirname(__file__), "forever_uncategorized.json")
if os.path.exists(uncat_json_path):
    with open(uncat_json_path, "r", encoding="utf-8") as f:
        uncat_mobs = json.load(f)
    uncat_matched = 0
    for mob in uncat_mobs:
        mid_str = str(mob.get('id'))
        if mid_str in retail_mask:
            r_info = retail_mask[mid_str]
            subf = r_info['subFamily']
            if subf in SUBFAMILY_SPECS:
                spec, elem, m1, m2, pup = SUBFAMILY_SPECS[subf]
                process_mob(mob, "Beast", subf, spec, elem, m1, m2, pup)
                uncat_matched += 1
        else:
            name = mob.get('name', '')
            if any(crit in name.lower() for crit in ['toad', 'frog', 'rat', 'mouse', 'hare', 'rabbit', 'snake', 'beetle', 'roach', 'moth', 'squirrel', 'fawn', 'deer']):
                process_mob(mob, "Critter", "Critter", "Cunning", "Beast", 101, 118, "Baby " + name)
    print(f"Matched {uncat_matched} Forever Uncategorized mobs into authentic Beast Subfamilies via Retail Mask.")
else:
    print("Warning: forever_uncategorized.json not found, skipping uncategorized mask pass.")

print(f"\n==========================================")
print(f"Total Unique Creatures Compiled: {len(master_creatures)}")
acq_counts = {}
subf_counts = {}
for c in master_creatures.values():
    acq_counts[c['acquisition']] = acq_counts.get(c['acquisition'], 0) + 1
    if c['family'] == 'Beast':
        subf_counts[c['subFamily']] = subf_counts.get(c['subFamily'], 0) + 1

for acq, cnt in acq_counts.items():
    print(f"  Acquisition {acq:10}: {cnt}")
print(f"Beast Subfamilies ({len(subf_counts)}):")
for sf, cnt in sorted(subf_counts.items()):
    print(f"  {sf:15}: {cnt}")
print(f"==========================================\n")

# -------------------------------------------------------------
# 5. EMIT LUA FILES
# -------------------------------------------------------------
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(BEASTS_DIR, exist_ok=True)

# Helper to write Lua partition
def write_lua_partition(filepath, var_name, mob_filter):
    with open(filepath, "w", encoding="utf-8") as f:
        f.write("-- Forever Safari — " + var_name + "\n")
        f.write("-- Auto-generated by Wowhead Scraper & Zone Taxonomy Pipeline\n\n")
        f.write("local _, FS = ...\n")
        f.write("FS = FS or {}\n")
        f.write(f"FS.{var_name} = {{\n")
        
        count = 0
        for nid, c in sorted(master_creatures.items()):
            if mob_filter(c):
                count += 1
                f.write(f"    [{nid}] = {{\n")
                f.write(f'        name = "{c["name"]}",\n')
                f.write(f'        family = "{c["family"]}",\n')
                f.write(f'        subFamily = "{c["subFamily"]}",\n')
                f.write(f'        spec = "{c["spec"]}",\n')
                f.write(f'        element = "{c["element"]}",\n')
                f.write(f'        minLevel = {c["minLevel"]},\n')
                f.write(f'        maxLevel = {c["maxLevel"]},\n')
                f.write(f'        classification = {c["classification"]},\n')
                f.write(f'        isBoss = {"true" if c["isBoss"] else "false"},\n')
                f.write(f'        zones = {{{", ".join(str(z) for z in c["zones"])} }},\n')
                f.write(f'        acquisition = "{c["acquisition"]}",\n')
                f.write(f'        allowBattle = {"true" if c["allowBattle"] else "false"},\n')
                f.write(f'        allowObservation = {"true" if c["allowObservation"] else "false"},\n')
                f.write(f'        isInstanceOnly = {"true" if c["isInstanceOnly"] else "false"},\n')
                if c["pupDropRate"] > 0:
                    f.write(f'        pupDropRate = {c["pupDropRate"]},\n')
                    f.write(f'        pupName = "{c["pupName"]}",\n')
                f.write(f'        moves = {{{c["moves"][0]}, {c["moves"][1]}}},\n')
                bs = c["baseStats"]
                f.write(f'        baseStats = {{ hp = {bs["hp"]}, atk = {bs["atk"]}, def = {bs["def"]}, spd = {bs["spd"]} }},\n')
                f.write("    },\n")
        f.write("}\n")
    print(f"Emitted {os.path.basename(filepath)}: {count} creatures.")

# Emit Individual Beast Subfamily Files
for subf in sorted(subf_counts.keys()):
    sanitized_sf = subf.replace(" ", "")
    fname = f"Creatures_Beasts_{sanitized_sf}.lua"
    fpath = os.path.join(BEASTS_DIR, fname)
    var_name = f"Creatures_Beasts_{sanitized_sf}"
    write_lua_partition(fpath, var_name, lambda c, s=subf: c['family'] == 'Beast' and c['subFamily'] == s)

# Remove old monolithic Creatures_Beasts.lua and Creatures_Beasts_Exotic.lua if they exist
old_beasts = os.path.join(OUTPUT_DIR, "Creatures_Beasts.lua")
if os.path.exists(old_beasts):
    os.remove(old_beasts)
    print(f"Removed old monolithic {old_beasts}")

old_exotic = os.path.join(BEASTS_DIR, "Creatures_Beasts_Exotic.lua")
if os.path.exists(old_exotic):
    os.remove(old_exotic)
    print(f"Removed old {old_exotic}")

# Emit Non-Beast Partition Files
write_lua_partition(os.path.join(OUTPUT_DIR, "Creatures_Dragonkin.lua"), "Creatures_Dragonkin", lambda c: c['family'] == "Dragonkin")
write_lua_partition(os.path.join(OUTPUT_DIR, "Creatures_Elementals.lua"), "Creatures_Elementals", lambda c: c['family'] == "Elemental")
write_lua_partition(os.path.join(OUTPUT_DIR, "Creatures_Mechanicals.lua"), "Creatures_Mechanicals", lambda c: c['family'] == "Mechanical")
write_lua_partition(os.path.join(OUTPUT_DIR, "Creatures_Undead.lua"), "Creatures_Undead", lambda c: c['family'] == "Undead")
write_lua_partition(os.path.join(OUTPUT_DIR, "Creatures_Other.lua"), "Creatures_Other", lambda c: c['family'] not in ("Beast", "Dragonkin", "Elemental", "Mechanical", "Undead"))

# Emit Zones Lua file
zones_path = os.path.join(OUTPUT_DIR, "Creatures_Zones.lua")
with open(zones_path, "w", encoding="utf-8") as f:
    f.write("-- Forever Safari — Master Zone Registry\n")
    f.write("-- Auto-generated by Wowhead Scraper & Zone Taxonomy Pipeline\n\n")
    f.write("local _, FS = ...\n")
    f.write("FS = FS or {}\n")
    f.write("FS.ZoneRegistry = {\n")
    for zid, z in sorted(zone_registry.items()):
        f.write(f"    [{zid}] = {{\n")
        f.write(f'        name = "{z["name"].replace(chr(34), chr(92)+chr(34))}",\n')
        f.write(f'        type = "{z["type"]}",\n')
        f.write(f'        isInstance = {"true" if z["isInstance"] else "false"},\n')
        f.write(f'        minLevel = {z.get("minLevel", 0)},\n')
        f.write(f'        maxLevel = {z.get("maxLevel", 0)},\n')
        f.write("    },\n")
    f.write("}\n")
print(f"Emitted Creatures_Zones.lua: {len(zone_registry)} zones.")

print("\nAll partitioned creature and zone registries generated successfully!")
