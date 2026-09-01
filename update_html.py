import re

with open('morphe_manager/www/index.html', 'r') as f:
    content = f.read()

# Replace the name extraction
old_name_extractor = """                let cleanName = mod.name.split('-')[0] || mod.name;
                cleanName = cleanName.charAt(0).toUpperCase() + cleanName.slice(1);"""

new_name_extractor = """                let baseName = mod.name.split('-universal')[0].split('-arm64')[0].split('-armeabi')[0];
                let cleanName = baseName.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');"""

content = content.replace(old_name_extractor, new_name_extractor)

# Add vibrate function
vibrate_script = """        const REPO = 'official-Arvind/Morphe-AutoBuilds';"""
vibrate_add = """        const REPO = 'official-Arvind/Morphe-AutoBuilds';
        
        function tryVibrate(ms) {
            try {
                if (navigator.vibrate) navigator.vibrate(ms);
            } catch(e) {}
        }"""
content = content.replace(vibrate_script, vibrate_add)

# Update switchTab to use vibrate
old_switchTab = """            event.target.classList.add('active');"""
new_switchTab = """            tryVibrate(30);
            event.target.classList.add('active');"""
content = content.replace(old_switchTab, new_switchTab)

# Update checkbox change to use vibrate
old_checkbox = """onchange="updateBtn(this)""""
new_checkbox = """onchange="tryVibrate(15); updateBtn(this)""""
content = content.replace(old_checkbox, new_checkbox)

# Add random roasts in installBtn click
old_installBtn = """            btn.disabled = true;
            btn.innerHTML = `<div class="loading-spinner"></div> Flashing... Please do not close`;
            showStatus('modules', "Downloading and installing modules... Device will reboot automatically on success.", 'info', true);"""

new_installBtn = """            btn.disabled = true;
            tryVibrate(50);
            btn.innerHTML = `<div class="loading-spinner"></div> Flashing... Please do not close`;
            
            const roasts = [
                "Downloading... if your internet isn't powered by a potato.",
                "Flashing... don't you dare touch that back button.",
                "Installing your shiny new modules. Hold your horses.",
                "Patching things up... hopefully you didn't pick anything conflicting.",
                "Doing the dirty work. Sit back and watch."
            ];
            const randomRoast = roasts[Math.floor(Math.random() * roasts.length)];
            
            showStatus('modules', randomRoast + " <br><br>Device will reboot automatically on success.", 'info', true);"""
content = content.replace(old_installBtn, new_installBtn)

# Update install status success
old_success = """                    showStatus('modules', "Flash successful! Rebooting device now...", 'success', true);"""
new_success = """                    tryVibrate([50, 50, 50]);
                    showStatus('modules', "Flash successful! 🚀 Your device is going down for a reboot now...", 'success', true);"""
content = content.replace(old_success, new_success)

# Update install status error
old_error = """                    showStatus('modules', `Installation failed:<br><pre style="margin-top:8px; font-size:11px; white-space:pre-wrap; background:rgba(0,0,0,0.2); padding:8px; border-radius:4px;">${text}</pre>`, 'error', true);"""
new_error = """                    tryVibrate([100, 50, 100]);
                    showStatus('modules', `Oof. That failed miserably. Here is why:<br><pre style="margin-top:8px; font-size:11px; white-space:pre-wrap; background:rgba(0,0,0,0.2); padding:8px; border-radius:4px;">${text}</pre>`, 'error', true);"""
content = content.replace(old_error, new_error)

with open('morphe_manager/www/index.html', 'w') as f:
    f.write(content)
