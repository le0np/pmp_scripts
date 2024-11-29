#!/bin/bash 

# Create domains.txt and paste a list of domains, one per line/row.
# Once done, you can run  the script to only get the domain and registrar name printed out
   
while read -r domain; do
    echo "Domain Name: $domain"
    whois "$domain" | grep "^Registrar URL:" 
    echo "--------------------------"
done < domains.txt
