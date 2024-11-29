#!/bin/bash

# Step 1: Extract domain names
echo "Extracting domain names..."
MYSQL_PWD=$(cat /etc/psa/.psa.shadow)
if ! mysql psa -uadmin -Ne "SELECT name FROM domains WHERE htype='vrt_hst'" > /root/list.txt; then
  echo "Error: Failed to fetch domains from the psa database."
  exit 1
fi
echo "Domain list saved to /root/list.txt"

# Step 2: Create php.txt file
echo "Creating /root/php.txt with open_basedir configuration..."
cat <<EOF > /root/php.txt
open_basedir = {WEBSPACEROOT}{/}{:}{TMP}{/}:/var/www/tmp/
EOF
echo "PHP settings file created: /root/php.txt"

# Step 3: Apply PHP settings
echo "Applying PHP settings to domains..."
if ! command -v /usr/local/psa/bin/site &>/dev/null; then
  echo "Error: Plesk 'site' command not found."
  exit 1
fi

while IFS= read -r DOMAIN; do
  if [[ -n "$DOMAIN" ]]; then
    /usr/local/psa/bin/site --update-php-settings "$DOMAIN" -settings /root/php.txt
    if [[ $? -eq 0 ]]; then
      echo "Updated PHP settings for $DOMAIN"
    else
      echo "Error: Failed to update PHP settings for $DOMAIN"
    fi
  fi
done < /root/list.txt

# Cleanup
rm -f /root/list.txt /root/php.txt

echo "All tasks completed."