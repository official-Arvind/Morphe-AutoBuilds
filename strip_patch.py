import re

with open(".github/workflows/patch.yml", "r") as f:
    content = f.read()

# We need to remove the "Build Morphe Manager" step.
# And we need to remove the references to update.json / morphe-manager.zip in Generate Release Notes & Upload Or Create Release.

# 1. Remove Build Morphe Manager
pattern = r"      - name: Build Morphe Manager\n.*?(?=      - name: Generate Release Notes)"
content = re.sub(pattern, "", content, flags=re.DOTALL)

# 2. In Generate Release Notes, remove update.json reference
remove_update_json_notes = r"""          if \[ -f \./release-apks/update\.json \]; then
            echo "update\.json" >> current_assets\.txt
          fi\n"""
content = re.sub(remove_update_json_notes, "", content)

# 3. In Upload Or Create Release, remove update.json reference
remove_update_json_upload = r"""          if \[ -f \./release-apks/update\.json \]; then
            ASSETS\+\=\( \./release-apks/update\.json \)
            echo "📎 Including update\.json"
          fi\n"""
content = re.sub(remove_update_json_upload, "", content)

with open(".github/workflows/patch.yml", "w") as f:
    f.write(content)

