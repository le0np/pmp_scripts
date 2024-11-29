#!/bin/bash

# Function to generate a new set of salt keys
generate_salt_keys() {
  curl -s https://api.wordpress.org/secret-key/1.1/salt/
}

# Define the path to search for wp-config.php files
base_path="/var/www/vhosts"

# Read domains from domains.txt
domains_file="domains.txt"
if [ ! -f "$domains_file" ]; then
  echo "domains.txt file not found!"
  exit 1
fi

# Iterate through each domain listed in domains.txt
while IFS= read -r domain; do
  # Construct the path to the wp-config.php file
  wp_config="$base_path/$domain/httpdocs/wp-config.php"
  
  # Check if wp-config.php file exists
  if [ -f "$wp_config" ]; then
    echo "Updating keys in: $wp_config"
    
    # Generate new salt keys
    new_keys=$(generate_salt_keys)
    
    # Create a backup of the original wp-config.php file
    cp "$wp_config" "${wp_config}.bak"
    
    # Remove the 9 lines above the /**#@-*/ and insert the new keys in the correct location
    awk -v new_keys="$new_keys" '
    BEGIN {
      split(new_keys, keys, "\n");
    }
    {
      buffer[NR] = $0;
      if ($0 ~ /\/\*\*#@-\*\//) {
        for (i = NR-8; i <= NR; i++) {
          delete buffer[i];
        }
        buffer[NR-9] = $0;
        for (i in keys) {
          buffer[NR-9] = keys[i] ORS buffer[NR-9];
        }
      }
    }
    END {
      for (i = 1; i <= NR; i++) {
        if (buffer[i] != "") {
          print buffer[i];
        }
      }
    }
    ' "$wp_config" > "${wp_config}.tmp" && mv "${wp_config}.tmp" "$wp_config"
    
    echo "Keys updated in: $wp_config"
  else
    echo "wp-config.php not found for domain: $domain"
  fi
done < "$domains_file"

echo "All wp-config.php files have been updated."

# Prompt user for file system repair
#read -p "Do you want to run file system repair for websites? (yes/no): " confirm
#if [[ "$confirm" =~ ^[Yy][Ee][Ss]|[Yy]$ ]]; then
plesk repair fs -vhosts -verbose -y
echo "File system repair has been executed."
#else
#echo "File system repair has been skipped."
#fi

# Prompt user to delete sample and backup config file
#read -p "Do you want to delete wp-config-sample.php and wp-config.php.bak (yes/no): " confirm
#if [[ "$confirm" =~ ^[Yy][Ee][Ss]|[Yy]$ ]]; then
find /var/www/vhosts/ -type f -name wp-config-sample.php -exec rm {} \;
find /var/www/vhosts/ -type f -name wp-config.php.bak -exec rm {} \;
echo "Config files have been removed."
# else
#  echo "Config files have not been removed."
#fi

