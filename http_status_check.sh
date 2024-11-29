#!/bin/bash

file="domains.txt"

while read -r domain; do
    curl -I "https://$domain" 2>/dev/null | grep HTTP | awk -v d="$domain" '{print d " = " $1" "$2}'
done < "$file"
