#!/bin/bash

# Path to the file
FILE="/var/www/html/blueprint.sh"

# Check if the file does not exist
if [ ! -f "$FILE" ]; then
    echo "File $FILE does not exist. Executing the script..."
    microdnf install -y ca-certificates curl gnupg nano wget git zip unzip findutils
    wget "$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)" -O release.zip
    unzip release.zip
fi
