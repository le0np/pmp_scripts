#!/bin/bash

read -p "Enter A record: "  a_record_target

for domain in $(cat domains.txt); do
  a_record=$(dig A $domain +short)
  if [ "$a_record" != "$a_record_target" ]; then
    echo $domain
  fi
done

