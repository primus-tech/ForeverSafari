#!/usr/bin/env python3
"""
Forever Safari — WoW Forever Display ID Scraper
Slow, rate-limited pull for cataloged creatures missing display IDs.
"""

import os
import sys
import json
import time
import random
import re
import glob
from playwright.sync_api import sync_playwright

WORKSPACE_DIR = "/home/primustech/.steam/debian-installation/steamapps/compatdata/4226358677/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/ForeverSafari"
PROGRESS_FILE = os.path.join(WORKSPACE_DIR, "Data", "ScrapeProgress.json")
DISPLAYS_FILE = os.path.join(WORKSPACE_DIR, "Data", "CreatureDisplays.lua")

def load_existing_displays():
    displays = {}
    if os.path.exists(DISPLAYS_FILE):
        with open(DISPLAYS_FILE, "r", encoding="utf-8") as f:
            for line in f:
                m = re.search(r'\[(\d+)\]\s*=\s*(\d+)', line)
                if m:
                    displays[int(m.group(1))] = int(m.group(2))
    return displays

def get_missing_creatures(existing_displays):
    creature_files = glob.glob(os.path.join(WORKSPACE_DIR, "Data", "Creatures", "*.lua"))
    creature_files += glob.glob(os.path.join(WORKSPACE_DIR, "Data", "Creatures", "Beasts", "*.lua"))

    creatures = {}
    for cfile in creature_files:
        if "Creatures_Zones.lua" in cfile:
            continue
        with open(cfile, "r", encoding="utf-8") as f:
            content = f.read()
            pattern = re.compile(r'\[(\d+)\]\s*=\s*\{([^}]+)\}', re.DOTALL)
            for m in pattern.finditer(content):
                npc_id = int(m.group(1))
                body = m.group(2)
                name_m = re.search(r'name\s*=\s*["\']([^"\']+)["\']', body)
                disp_m = re.search(r'displayId\s*=\s*(\d+)', body)
                name = name_m.group(1) if name_m else "Unknown"
                disp = int(disp_m.group(1)) if disp_m else 0
                creatures[npc_id] = {
                    "id": npc_id,
                    "name": name,
                    "file_displayId": disp
                }

    # Filter to those missing from displays or with 0
    missing = []
    for npc_id, info in creatures.items():
        if npc_id not in existing_displays or existing_displays[npc_id] == 0:
            missing.append(info)

    # Sort deterministically by NPC ID
    missing.sort(key=lambda x: x["id"])
    return missing

def load_progress():
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"[Warning] Failed to load progress: {e}")
    return {}

def save_progress(progress):
    try:
        tmp_file = PROGRESS_FILE + ".tmp"
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(progress, f, indent=2)
        os.replace(tmp_file, PROGRESS_FILE)
    except Exception as e:
        print(f"[Error] Failed to save progress: {e}")

def update_creature_displays_lua(new_displays):
    """Safely merges new verified display IDs into Data/CreatureDisplays.lua"""
    existing = load_existing_displays()
    updated_count = 0
    for nid_str, disp in new_displays.items():
        nid = int(nid_str)
        if disp and disp > 0:
            if nid not in existing or existing[nid] != disp:
                existing[nid] = disp
                updated_count += 1

    lines = [
        "-- Forever Safari — Pre-Baked Wowhead Forever CreatureDisplayInfo DB",
        "-- Auto-compiled from official WoW Forever (1.60.1) scrape data",
        "-- Pairs NPC Template ID -> 3D Display Model ID for modern ModelFrame rendering.",
        "",
        "local _, FS = ...",
        "FS = FS or {}",
        "",
        "FS.CreatureDisplays = {"
    ]

    for nid in sorted(existing.keys()):
        lines.append(f"    [{nid}] = {existing[nid]},")

    lines.append("}")
    lines.append("")

    with open(DISPLAYS_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"[Success] Updated {DISPLAYS_FILE} with {len(existing)} total entries ({updated_count} newly integrated).")

def main():
    existing_displays = load_existing_displays()
    print(f"Loaded {len(existing_displays)} existing display IDs from CreatureDisplays.lua")

    missing = get_missing_creatures(existing_displays)
    print(f"Found {len(missing)} creatures requiring display IDs.")

    progress = load_progress()
    print(f"Loaded {len(progress)} cached scrape results from ScrapeProgress.json")

    # Filter out already scraped in progress
    todo = [c for c in missing if str(c["id"]) not in progress]
    print(f"Total remaining to scrape: {len(todo)}")

    if not todo:
        print("All missing creatures have already been fetched! Merging to CreatureDisplays.lua...")
        update_creature_displays_lua(progress)
        return

    print("Launching Chromium headless engine...")
    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path="/usr/bin/google-chrome",
            headless=True,
            args=["--disable-blink-features=AutomationControlled", "--no-sandbox"]
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
        )
        page = context.new_page()

        # Block images and fonts to save memory and network overhead
        page.route("**/*.{png,jpg,jpeg,gif,webp,svg,woff,woff2,ttf,eot,mp4,mp3}", lambda route: route.abort())

        total = len(todo)
        success_count = 0
        not_found_count = 0

        for idx, creature in enumerate(todo, 1):
            npc_id = creature["id"]
            name = creature["name"]
            url = f"https://www.wowhead.com/forever/npc={npc_id}"

            try:
                page.goto(url, timeout=25000, wait_until="domcontentloaded")
                # Wait 1.2s for DOM and any lightbox script bindings to settle
                page.wait_for_timeout(1200)

                content = page.content()
                
                # Check for displayId in linksButton or ModelViewer lightbox
                m = re.search(r'dataset\.displayId\s*=\s*(\d+)', content)
                if not m:
                    m = re.search(r'data-mv-display-id="(\d+)"', content)
                if not m:
                    m = re.search(r'WH\.Wow\.ModelViewer\.showLightbox\(\{[^}]*["\']displayId["\']\s*:\s*(\d+)', content)

                if m:
                    display_id = int(m.group(1))
                    progress[str(npc_id)] = display_id
                    success_count += 1
                    print(f"[{idx}/{total}] NPC {npc_id} ({name}): MATCH displayId = {display_id}")
                else:
                    # Check if 404 or no model viewer
                    if "Page Not Found" in page.title() or "Error 404" in content:
                        print(f"[{idx}/{total}] NPC {npc_id} ({name}): 404 Not Found on WoW Forever")
                        progress[str(npc_id)] = 0
                    else:
                        print(f"[{idx}/{total}] NPC {npc_id} ({name}): No 3D model found on page")
                        progress[str(npc_id)] = 0
                    not_found_count += 1

                # Save checkpoint immediately
                save_progress(progress)

            except Exception as e:
                print(f"[{idx}/{total}] NPC {npc_id} ({name}) error: {e}")
                # Wait longer on error before next attempt
                time.sleep(10.0)

            # Politeness delay: 3.0 to 6.0 seconds jitter
            if idx < total:
                delay = random.uniform(3.0, 6.0)
                time.sleep(delay)

            # Periodic sync to CreatureDisplays.lua every 25 entries
            if idx % 25 == 0:
                print(f"--- Periodic Checkpoint ({idx}/{total}) ---")
                update_creature_displays_lua(progress)

        browser.close()

    print("\nScraping run completed! Writing final CreatureDisplays.lua...")
    update_creature_displays_lua(progress)
    print("Done!")

if __name__ == "__main__":
    main()
