#!/bin/bash

# Path to the file
FILE="/var/www/html/blueprint.sh"

# Check if the file does not exist
if [ ! -f "$FILE" ]; then
    echo "File $FILE does not exist. Executing the script..."
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - && \
    microdnf install -y nodejs && \
    microdnf clean all
    npm i -g yarn
    microdnf install -y unzip
    microdnf install -y ca-certificates
    microdnf install -y gnupg
    microdnf install -y nano
    microdnf install -y wget
    microdnf install -y git
    microdnf install -y zip
    microdnf install -y findutils
    wget "$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)" -O release.zip
    unzip -o release.zip
    echo -e "DOCKER='n'\nFOLDER='/var/www/html'" > .blueprintrc
    chmod +x blueprint.sh
    yarn install
    ./blueprint.sh
    adduser --user-group www-data
    chmod -R 777 /var/www/html
    # Place the commands you want to execute here
    # Example: Create the blueprint.sh file or other tasks
    # touch "$FILE"  # Uncomment if you want to create the file
fi
yacron -c /etc/yacron/yacron.yml &
