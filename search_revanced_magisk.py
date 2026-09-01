import urllib.request
import json
import base64

try:
    req = urllib.request.Request("https://api.github.com/repos/j-hc/revanced-magisk-module/contents/template")
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        for file in data:
            if file["name"] in ["service.sh", "post-fs-data.sh", "customize.sh"]:
                print(f"--- {file['name']} ---")
                req_file = urllib.request.Request(file["url"])
                with urllib.request.urlopen(req_file) as response_file:
                    file_data = json.loads(response_file.read().decode())
                    if "content" in file_data:
                        print(base64.b64decode(file_data["content"]).decode())
except Exception as e:
    print(e)
