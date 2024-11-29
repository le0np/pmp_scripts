#!/bin/bash

# Log start time
echo "Starting Let's Encrypt renewal: $(date)" >> letsencrypt.log

# Loop through each directory in /var/www/vhosts
for domain_path in /var/www/vhosts/*; do
    # Extract just the domain name from the full path
    domain=$(basename "$domain_path")

    # Skip the directories we want to exclude
    if [[ "$domain" == "chroot" || "$domain" == "default" || "$domain" == "system" ]]; then
        #echo "Skipping excluded directory: $domain" >> letsencrypt.log
        continue
    fi

    # Log the domain being processed
    echo "Processing $domain" >> letsencrypt.log

    # Run the Plesk Let's Encrypt command for the domain and its www subdomain
    output=$(plesk bin extension --exec letsencrypt cli.php -d "$domain" -d "www.$domain" -m leon@postmarketpublishing.com --renew 2>&1)

    if [ $? -eq 0 ]; then
        # Log success
        echo "Successfully renewed certificate for $domain" >> letsencrypt.log
    else
        # Log failure with actual error message
        echo "Failed to renew certificate for $domain" >> letsencrypt.log
        echo "Error details: $output" >> letsencrypt.log
    fi
done

# Log end time
echo "Let's Encrypt renewal completed: $(date)" >> letsencrypt.log
