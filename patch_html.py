with open("morphe_manager/www/index.html", "r") as f:
    content = f.read()

import re

old_js = """                const res = await fetch('/cgi-bin/install.sh', {
                    method: 'POST',
                    body: JSON.stringify({ urls })
                });
                
                const text = await res.text();
                if (res.ok && text.includes("SUCCESS")) {
                    tryVibrate([50, 50, 50]);
                    showStatus('modules', "✨ Flash successful! Your device is going down for a reboot now...", 'success', true);
                } else {
                    tryVibrate([100, 50, 100]);
                    showStatus('modules', `🔥 Oof. That failed miserably. Here is why:<br><pre style="margin-top:8px; font-size:11px; white-space:pre-wrap; background:rgba(0,0,0,0.2); padding:8px; border-radius:4px;">${text.trim() || 'No logs. Did you even send something?'}</pre>`, 'error', true);
                    updateBtn(null);
                }"""

new_js = """                const res = await fetch('/cgi-bin/install.sh', {
                    method: 'POST',
                    body: JSON.stringify({ urls })
                });
                
                const text = await res.text();
                if (res.ok && text.includes("QUEUED")) {
                    showStatus('modules', "✨ Request queued! Starting background flasher...", 'success', true);
                    
                    const pollInterval = setInterval(async () => {
                        try {
                            const statusRes = await fetch('/cgi-bin/status.sh');
                            if (statusRes.ok) {
                                const statusText = await statusRes.text();
                                
                                if (statusText.includes("STATUS: SUCCESS")) {
                                    clearInterval(pollInterval);
                                    tryVibrate([50, 50, 50]);
                                    showStatus('modules', `✨ Flash successful! Device is rebooting...<br><pre style="margin-top:8px; font-size:11px; white-space:pre-wrap; background:rgba(0,0,0,0.2); padding:8px; border-radius:4px; max-height:150px; overflow-y:auto;">${statusText.trim()}</pre>`, 'success', true);
                                } else if (statusText.includes("STATUS: FAILURE")) {
                                    clearInterval(pollInterval);
                                    tryVibrate([100, 50, 100]);
                                    showStatus('modules', `🔥 Oof. That failed miserably. Here is why:<br><pre style="margin-top:8px; font-size:11px; white-space:pre-wrap; background:rgba(0,0,0,0.2); padding:8px; border-radius:4px; max-height:150px; overflow-y:auto;">${statusText.trim()}</pre>`, 'error', true);
                                    updateBtn(null);
                                } else if (statusText.trim() !== "" && statusText.trim() !== "WAITING") {
                                    // Live updates
                                    showStatus('modules', `<div style="display:flex; align-items:center; gap:8px;"><div class="loading-spinner" style="width:14px;height:14px;"></div> <b>Flashing in background...</b></div><pre id="liveLogs" style="margin-top:8px; font-size:11px; white-space:pre-wrap; background:rgba(0,0,0,0.2); padding:8px; border-radius:4px; max-height:150px; overflow-y:auto;">${statusText.trim()}</pre>`, '', true);
                                    // Auto scroll logs
                                    const logEl = document.getElementById('liveLogs');
                                    if(logEl) logEl.scrollTop = logEl.scrollHeight;
                                }
                            }
                        } catch (e) {
                            // ignore fetch errors during polling
                        }
                    }, 1000);
                } else {
                    tryVibrate([100, 50, 100]);
                    showStatus('modules', `🔥 Failed to queue request:<br><pre style="margin-top:8px; font-size:11px; white-space:pre-wrap; background:rgba(0,0,0,0.2); padding:8px; border-radius:4px;">${text.trim() || 'No logs.'}</pre>`, 'error', true);
                    updateBtn(null);
                }"""

if old_js in content:
    content = content.replace(old_js, new_js)
    with open("morphe_manager/www/index.html", "w") as f:
        f.write(content)
    print("Patched index.html successfully!")
else:
    print("Could not find the target javascript to replace in index.html!")

