#!/usr/bin/env python3
import json
import re
import os

STEPS_DIR = "/home/primustech/.gemini/antigravity-ide/brain/40abe491-18a6-4c46-aebf-9a1bf9235bef/.system_generated/steps"
OUTPUT_DIR = "/home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari/Data/Creatures"

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

zone_registry = {} # zid -> { id, name, type, isInstance }

# First load from step files
for ztype, step_num in zone_steps.items():
    html = load_step_file(step_num)
    data = parse_listview_data(html)
    is_inst = ztype in ('dungeon', 'raid')
    for z in data:
        zid = z.get('id')
        name = z.get('name')
        zone_registry[zid] = {
            'id': zid,
            'name': name,
            'type': ztype,
            'isInstance': is_inst,
            'minLevel': z.get('minlevel', 0),
            'maxLevel': z.get('maxlevel', 0)
        }

# Augment from Wowhead filter dropdown
for zid, (zname, group) in filter_zones.items():
    if zid not in zone_registry:
        is_inst = group in ('Battlegrounds', 'Dungeons', 'Raids') or zid == 2159 # Onyxia's Lair
        gtype = 'battleground' if group == 'Battlegrounds' else ('dungeon' if group == 'Dungeons' else ('raid' if (group == 'Raids' or zid == 2159) else 'open_world'))
        zone_registry[zid] = {
            'id': zid,
            'name': zname,
            'type': gtype,
            'isInstance': is_inst,
            'minLevel': 0,
            'maxLevel': 0
        }

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
        
    # Exclude obvious humanoid guard/civilian roles in uncategorized/undead
    bad_names = ['citizen', 'peasant', 'guard', 'apprentice', 'innkeeper', 'bartender', 'lieutenant', 'captain', 'magistrate']
    if any(name.startswith(bn + ' ') or name.endswith(' ' + bn) or name == bn for bn in bad_names):
        # But allow animal named guards if any
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

def process_mob(mob, family, spec, element, move1, move2, default_pup_name):
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
    
    pup_name = f"{name} Pup" if not default_pup_name else default_pup_name
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
    elif "Scrap" in default_pup_name:
        pup_name = f"{name} Micro-Bot"
    
    master_creatures[nid] = {
        'id': nid,
        'name': name,
        'family': family,
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
        process_mob(mob, family, spec, element, m1, m2, pup_name)

# B. General Beasts
print("--> Processing General Beasts...")
beasts_html = load_step_file(2558)
for mob in parse_listview_data(beasts_html):
    process_mob(mob, "Beast", "Ferocity", "Beast", 101, 118, "Beast Pup")

# C. Dragonkin
print("--> Processing Dragonkin...")
dragon_html = load_step_file(2534)
for mob in parse_listview_data(dragon_html):
    process_mob(mob, "Dragonkin", "Dragonkin", "Dragonkin", 101, 806, "Whelp")

# D. Elementals
print("--> Processing Elementals...")
elem_html = load_step_file(2560)
for mob in parse_listview_data(elem_html):
    process_mob(mob, "Elemental", "Elemental", "Elemental", 301, 307, "Elemental Spark")

# E. Mechanicals
print("--> Processing Mechanicals...")
mech_html = load_step_file(2562)
for mob in parse_listview_data(mech_html):
    process_mob(mob, "Mechanical", "Mechanical", "Mechanical", 601, 607, "Scrap-Bot")

# F. Undead
print("--> Processing Undead...")
undead_html = load_step_file(2566)
for mob in parse_listview_data(undead_html):
    process_mob(mob, "Undead", "Undead", "Shadow", 201, 204, "Bone Pup")

# G. Uncategorized (Critters & Wildlife)
print("--> Processing Uncategorized...")
uncat_html = load_step_file(2564)
for mob in parse_listview_data(uncat_html):
    # Only keep wildlife/critters
    name = mob.get('name', '')
    if any(crit in name.lower() for crit in ['toad', 'frog', 'rat', 'mouse', 'hare', 'rabbit', 'snake', 'beetle', 'roach', 'moth', 'squirrel', 'fawn', 'deer', 'prairie dog']):
        process_mob(mob, "Critter", "Cunning", "Beast", 101, 118, "Baby " + name)

print(f"\n==========================================")
print(f"Total Unique Creatures Compiled: {len(master_creatures)}")
acq_counts = {}
fam_counts = {}
for c in master_creatures.values():
    acq_counts[c['acquisition']] = acq_counts.get(c['acquisition'], 0) + 1
    fam_counts[c['family']] = fam_counts.get(c['family'], 0) + 1

for acq, cnt in acq_counts.items():
    print(f"  Acquisition {acq:10}: {cnt}")
print(f"Families: {len(fam_counts)}")
print(f"==========================================\n")

# -------------------------------------------------------------
# 5. EMIT LUA FILES
# -------------------------------------------------------------
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Helper to write Lua partition
def write_lua_partition(filename, var_name, mob_filter):
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Forever Safari — " + var_name + "\n")
        f.write("-- Auto-generated by Wowhead Scraper & Zone Taxonomy Pipeline\n\n")
        f.write("local _, FS = ...\n")
        f.write("FS = FS or {}\n")
        f.write(f"FS.{var_name} = {{\n")
        
        count = 0
        for nid, c in master_creatures.items():
            if mob_filter(c):
                count += 1
                f.write(f"    [{nid}] = {{\n")
                f.write(f'        name = "{c["name"]}",\n')
                f.write(f'        family = "{c["family"]}",\n')
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
    print(f"Emitted {filename}: {count} creatures.")

# Partition files
beast_fams = set(beast_subcats.keys()) | {"Beast"}
write_lua_partition("Creatures_Beasts.lua", "Creatures_Beasts", lambda c: c['family'] in beast_fams)
write_lua_partition("Creatures_Dragonkin.lua", "Creatures_Dragonkin", lambda c: c['family'] == "Dragonkin")
write_lua_partition("Creatures_Elementals.lua", "Creatures_Elementals", lambda c: c['family'] == "Elemental")
write_lua_partition("Creatures_Mechanicals.lua", "Creatures_Mechanicals", lambda c: c['family'] == "Mechanical")
write_lua_partition("Creatures_Undead.lua", "Creatures_Undead", lambda c: c['family'] == "Undead")
write_lua_partition("Creatures_Other.lua", "Creatures_Other", lambda c: c['family'] not in (beast_fams | {"Dragonkin", "Elemental", "Mechanical", "Undead"}))

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

print("\nAll creature and zone registries generated successfully!")
