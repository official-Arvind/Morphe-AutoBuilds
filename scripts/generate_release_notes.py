import sys
import json
from collections import defaultdict
from pathlib import Path
import re

def generate_notes():
    assets_file = Path("release_assets.txt")
    if not assets_file.exists():
        print("release_assets.txt not found")
        sys.exit(1)

    with assets_file.open("r", encoding="utf-8") as f:
        assets = sorted([line.strip() for line in f if line.strip()])

    repo_url = "https://github.com/official-Arvind/Morphe-AutoBuilds/releases/download/latest"

    # Grouping logic
    # Filenames are typically: {app_name}-{arch}-patch-v{version}.apk or -root-{name}-v{version}.zip
    apps = defaultdict(list)
    for asset in assets:
        if asset in ["manifest.json", "morphe-manager.zip", "update.json"]:
            apps["System / Core"].append(asset)
            continue
        
        # Simple heuristic to extract app name (first word before dash)
        match = re.match(r"^([a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*?)-(universal|arm64-v8a|armeabi-v7a|x86|x86_64)", asset)
        if match:
            app_name = match.group(1).title().replace("-", " ")
        else:
            app_name = asset.split("-")[0].title()
        apps[app_name].append(asset)

    with open("release_notes.md", "w", encoding="utf-8") as out:
        out.write("# Morphe APKs - Auto Built\n\n")
        out.write("## 📱 Available Apps\n\n")
        
        for app_name in sorted(apps.keys()):
            out.write(f"### 📦 {app_name}\n")
            # Sort non-root (.apk) first, then root (.zip)
            app_assets = sorted(apps[app_name], key=lambda x: (not x.endswith('.apk'), x))
            for asset in app_assets:
                download_url = f"{repo_url}/{asset}"
                
                # Determine type for clean display
                if asset.endswith(".apk"):
                    type_badge = "🟢 `Non-Root`"
                elif asset.endswith(".zip") and asset != "morphe-manager.zip":
                    type_badge = "🔴 `Magisk/Root`"
                else:
                    type_badge = "⚙️ `System`"
                
                out.write(f"- {type_badge} [{asset}]({download_url})\n")
            out.write("\n")
            
        out.write("---\n\n")
        out.write("## ⚙️ Build Information\n")
        out.write("- **Auto-built daily at 6 AM UTC**\n")
        out.write("- **Multiple architecture support** (arm64-v8a, armeabi-v7a, universal)\n")
        out.write("- **Latest Morphe patches**\n")
        out.write("- **Updated automatically**\n\n")
        
        out.write("## 📊 Architecture Guide\n")
        out.write("- **arm64-v8a**: Modern ARM devices (2014+)\n")
        out.write("- **armeabi-v7a**: Older ARM devices\n")
        out.write("- **universal**: All ARM devices (larger file)\n\n")
        
        out.write("## ⚠️ Disclaimer\n")
        out.write("These APKs are built automatically. Use at your own risk.\n")

if __name__ == "__main__":
    generate_notes()
