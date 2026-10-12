import urllib.request, json, time, os, re

# The relevant Retail Pet Families
PET_FAMILIES = {
    1: 'Wolf',
    2: 'Cat',
    3: 'Spider',
    4: 'Bear',
    5: 'Boar',
    6: 'Crocolisk',
    7: 'Carrion Bird',
    8: 'Crab',
    9: 'Gorilla',
    11: 'Raptor',
    12: 'Tallstrider',
    20: 'Scorpid',
    21: 'Turtle',
    24: 'Bat',
    25: 'Hyena',
    26: 'Bird of Prey',
    27: 'Wind Serpent',
    35: 'Serpent',
    38: 'Chimaera',
    39: 'Devilsaur',
    41: 'Silithid',
    42: 'Worm',
    43: 'Kodo', # Clefthoof
    44: 'Silithid', # Wasp
    45: 'Core Hound',
    50: 'Fox',
    52: 'Wolf', # Hound
    53: 'Spider', # Beetle
    68: 'Hydra',
    130: 'Basilisk',
    151: 'Stag',
    156: 'Dinosaur', # Scalehide
    288: 'Basilisk', # Lizard
    290: 'Bird of Prey', # Pterrordax
    299: 'Stag', # Courser
}

def parse_listview_data(html_content):
    match = re.search(r'new Listview\((\{.*?\})\);', html_content, re.DOTALL)
    if not match:
        match = re.search(r'data:\s*(\[\{.*?\}\])', html_content, re.DOTALL)
        if not match:
            return []
        raw_json = match.group(1)
    else:
        raw_json = match.group(1)
    
    data_match = re.search(r'\"data\":\s*(\[\s*\{.*?\}\s*\])', raw_json, re.DOTALL)
    if not data_match:
        data_match = re.search(r'data:\s*(\[\s*\{.*?\}\s*\])', raw_json, re.DOTALL)
    
    if data_match:
        data_str = data_match.group(1)
        data_str = re.sub(r'\"[a-zA-Z0-9_-]+\":function\(.*?\)\{.*?\},?', '', data_str)
        data_str = re.sub(r',\s*([\]\}])', r'\1', data_str)
        try:
            return json.loads(data_str)
        except:
            items = []
            for obj in re.finditer(r'\{[^{}]*\"id\":\s*(\d+)[^{}]*\}', data_str):
                id_val = int(obj.group(1))
                name_match = re.search(r'\"name\":\s*\"([^\"]+)\"', obj.group(0))
                name_val = name_match.group(1) if name_match else "Unknown"
                type_match = re.search(r'\"type\":\s*(\d+)', obj.group(0))
                type_val = int(type_match.group(1)) if type_match else 1
                items.append({'id': id_val, 'name': name_val, 'type': type_val})
            return items
    return []

cache_file = os.path.join(os.path.dirname(__file__), 'retail_pet_mask.json')
if os.path.exists(cache_file):
    with open(cache_file, 'r', encoding='utf-8') as f:
        mask = json.load(f)
else:
    mask = {}

print(f'Starting Retail Mask extraction. Existing cached: {len(mask)}')

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

for fam_id, fam_name in sorted(PET_FAMILIES.items()):
    url = f'https://www.wowhead.com/npcs?filter=52;{fam_id};0'
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode('utf-8', errors='ignore')
            mobs = parse_listview_data(content)
            added = 0
            for m in mobs:
                mid = str(m.get('id'))
                if mid:
                    if mid not in mask:
                        mask[mid] = {
                            'id': int(mid),
                            'name': m.get('name'),
                            'family': 'Beast',
                            'subFamily': fam_name,
                            'type': m.get('type')
                        }
                        added += 1
            print(f'Family {fam_id:3} ({fam_name:<12}): fetched {len(mobs):4} mobs, +{added} new in mask.')
    except Exception as e:
        print(f'Family {fam_id} error: {e}')
    time.sleep(0.3)

with open(cache_file, 'w', encoding='utf-8') as f:
    json.dump(mask, f, indent=2)

print(f'\nSaved Retail Mask to {cache_file}: Total {len(mask)} NPCs classified!')
