#!/bin/bash

plugin_slug="mailgun"

while IFS= read -r domain; do
    instance_id=$(plesk ext wp-toolkit --list | grep -w "$domain" | awk '{print $1}')

    if [[ -n "$instance_id" ]]; then
        echo "Installing "$plugin_slug" plugin for $domain (Instance ID: $instance_id)..."
        plesk ext wp-toolkit --wp-cli -instance-id "$instance_id" -- plugin install "$plugin_slug"
    fi
done < domains.txt
