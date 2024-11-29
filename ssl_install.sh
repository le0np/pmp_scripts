#!/bin/bash

# SSL INSTALLATION SCRIPT
#
# DESCRIPTION:
# This Bash script automates the installation of Let's Encrypt SSL certificates for domains specified in the 'domains.txt' file. 
# It prompts the user to choose SSL installation options for non-www, www, or both, and then requests the certificates accordingly. 
# The script uses Plesk CLI commands for Let's Encrypt and logs the installation details in a file named 'letsencrypt.log'. 
#
# USAGE:
# 1. Place domain names in 'domains.txt'.
# 2. Run the script.
# 3. Choose SSL installation options: non-www (1), www (2), or both (3).
# 4. Monitor the installation progress in 'letsencrypt.log'.
# 5. Optionally, configure your web server to use the SSL certificates and restart the server.
#
# NOTE:
# - Tested on Ubuntu 20.04.6 LTS with Plesk Obsidian 18.0.57.5.
# - Ensure 'domains.txt' is present in the same directory.
# - Adjust server-specific configurations as needed.
#
# AUTHOR: le0np
# DATE: 19/01/2024

# Define a log file to capture the output
log_file="letsencrypt.log"

# Define admin email address
read -p "Enter email for SSL: " admin_email

# Clear letsencrypt.log 
echo "" > $log_file

# Check if the domains.txt file exists
if [ ! -f "domains.txt" ]; then
   echo "domains.txt file not found." | tee -a "$log_file"
   exit 1
fi

# Ask the user to choose an option: 1 for non-www, 2 for www, 3 for both
echo "Choose an option:"
echo "1. Install SSL on non-www"
echo "2. Install SSL on www"
echo "3. Install SSL on both www and non-www"
read -r ssl_option

# Loop through the domains in domains.txt and request Let's Encrypt certificates based on user input
while IFS= read -r domain; do
   echo "Requesting certificate for $domain..." | tee -a "$log_file"
   
   case "$ssl_option" in
      1)
         # Request certificate for domain.com
         if plesk bin extension --exec letsencrypt cli.php -d "$domain" -m "$admin_email" >> "$log_file" 2>&1; then
            echo "SSL successfully installed for $domain" | tee -a "$log_file"
         else
            echo "Failed to install SSL for $domain" | tee -a "$log_file"
         fi
         ;;
      2)
         # Request certificate for www.domain.com
         if plesk bin extension --exec letsencrypt cli.php -d "www.$domain" -m "$admin_email" >> "$log_file" 2>&1; then
            echo "SSL successfully installed for www.$domain" | tee -a "$log_file"
         else
            echo "FAILED TO INSTALL SSL FOR www.$domain" | tee -a "$log_file"
         fi
         ;;
      3)
         # Request certificates for both www.domain.com and domain.com
         if plesk bin extension --exec letsencrypt cli.php -d "$domain" -d "www.$domain" -m "$admin_email" >> "$log_file" 2>&1; then
            echo "SSL successfully installed for $domain and www.$domain" | tee -a "$log_file"
         else
            echo "FAILED TO INSTALL SSL FOR $domain and www.$domain" | tee -a "$log_file"
         fi
         ;;
      *)
         echo "Invalid input. Please enter 1, 2, or 3." | tee -a "$log_file"
         exit 1
         ;;
   esac
done < "domains.txt"

# Restart your web server (e.g., Apache or Nginx) to apply the changes.
# For Apache:
systemctl restart apache2
# For Nginx:
systemctl restart nginx

# Improve logging... 
