with open("morphe_manager/www/cgi-bin/install.sh", "r") as f:
    content = f.read()

content = content.replace('curl -L -s -o "$FILE" "$URL"', 'curl -f -L -s -o "$FILE" "$URL"')
with open("morphe_manager/www/cgi-bin/install.sh", "w") as f:
    f.write(content)

with open("morphe_manager/auto_update.sh", "r") as f:
    content = f.read()

content = content.replace('curl -L -s -o', 'curl -f -L -s -o')
with open("morphe_manager/auto_update.sh", "w") as f:
    f.write(content)
