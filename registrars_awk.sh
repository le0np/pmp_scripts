#!/bin/bash

# Create domains.txt and paste a list of domains, one per line/row.
# Once done, you can run the script to only get the domain and registrar URL printed out

while IFS= read -r domain; do
    echo "Domain Name: $domain"
    registrar_info=$(whois "$domain" | awk -F ':' '/Registrar URL|Registrar/ {print "Registrar URL: " $2}' | head -n 1)

    if [[ -z $registrar_info ]]; then
        echo "Registrar information not found or in an unexpected format."
    else
        echo "$registrar_info"
    fi

    echo "--------------------------"
done < domains.txt

