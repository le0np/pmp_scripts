#!/bin/bash

# Loop through each directory in /var/www/vhosts, excluding chroot and system directories
for dir in $(find /var/www/vhosts -mindepth 1 -maxdepth 1 -type d ! -name 'chroot' ! -name 'system'); do
    # Extract domain name from the directory path
    domain=$(basename "$dir")

    echo "Checking SSL certificate for $domain..."

    # Run curl to check SSL certificate details
    curl --insecure -v "https://$domain" 2>&1 | awk '
        /^\*  subject:/ { print $0 }
        /^\*  issuer:/ { print $0 }
        /^\*  SSL certificate verify ok\./ { print $0; print ""; exit }
    '
done
