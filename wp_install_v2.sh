#!/bin/bash
#
# DESCRIPTION: 
# This script reads domain names from the 'domains.txt' file, attempting to install a default WordPress website for each domain.
# It has been tested on Ubuntu 20.04.6 LTS with Plesk Obsidian 18.0.57.5.
#
# NOTE: This script assumes that 'wp-cli' and 'php-mysql' are not already installed, and it uses 'domains.txt' for domain names.
# Adjustments may be needed based on specific server configurations and requirements.
#
# AUTHOR: le0np
# DATE: 30/04/2024

#set -e  # Stop on errors
#set -x  # Print commands as they execute (for debugging)

# Update packages 
apt update -y && apt upgrade -y

# Check if PHP-CLI is already installed
if command -v php &> /dev/null; then
    echo -e "PHP-CLI is already installed.\n"
else
    # Install PHP 7.4 CLI
    echo "Installing PHP-CLI ....."
    apt install php7.4-cli -y | tee -a credentials.txt
fi

# Check if wp-cli is already installed
if command -v wp &> /dev/null; then
    echo -e "wp-cli is already installed.\n"
else
    # Install wp-cli
    echo "Installing WP-CLI ....."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar | tee -a credentials.txt
    chmod +x wp-cli.phar | tee -a credentials.txt
    mv wp-cli.phar /usr/local/bin/wp | tee -a credentials.txt
    wp --info | tee -a credentials.txt
fi

# Check if php-mysql is already installed
if ! dpkg -s php-mysql &> /dev/null; then
    # Install php-mysql
    echo "Installing PHP-MYSQL ....."
    apt install php-mysql -y | tee -a credentials.txt
else
    echo -e "php-mysql is already installed.\n" | tee -a credentials.txt
fi

# Assign domains file
domains="domains.txt"
letsencrypt_log="letsencrypt.log"

# Assign IP address 
ip=$(hostname -I | awk '{print $1}')

# Database and SSL configurations
db_host="localhost"
read -p "Enter email for SSL install: " ssl_email

# Create or clear the credentials.txt file and letsencrypt log file
> credentials.txt
> "$letsencrypt_log"  # Corrected to use the variable and ensure the file is created

# Function to generate a valid password
generate_password() {
    local admin_pass special_char_count
    while true; do
        # Generate a password with the specified character set
        admin_pass=$(tr -dc 'A-Za-z0-9!#$%&()*-<>?@^_~' < /dev/urandom | head -c 16)
        
        # Count the number of special characters
        special_char_count=$(echo "$admin_pass" | grep -o '[!#$%&()*-<>?@^_~]' | wc -l)
        
        # Ensure the first character is not a special character and special characters are limited to 2-3
        if [[ ${admin_pass:0:1} =~ [A-Za-z0-9] && $special_char_count -ge 2 && $special_char_count -le 3 ]]; then
            echo "$admin_pass"
            return
        fi
    done
}

# Maximum number of retries for SSL installation
max_retries=3

# Loop through each domain
for domain in $(cat "$domains"); do
  # Generate random string for the admin username
  random_string=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)  # Adjust the length as needed

  # Generate database name and user
  db_name="wp_${domain//./_}"
  db_user="user_${domain//./_}"
  db_password=$(openssl rand -base64 20)

  # Set up database and user
  mysql -e "CREATE DATABASE IF NOT EXISTS \`$db_name\`; GRANT ALL ON \`$db_name\`.* TO '$db_user'@'$db_host' IDENTIFIED BY '$db_password'; FLUSH PRIVILEGES;" | tee -a credentials.txt

  # Create website subscription
  admin_user="pmp_admin_$random_string"
  
  # Generate a valid admin password using the function
  admin_pass=$(generate_password)
  
  title="${domain%%.*}"
  email="info@$domain"
  service_plan="Default Domain"
  create_output=$(plesk bin subscription --create $domain -service-plan "$service_plan" -ip "$ip" -login "$admin_user" -passwd "$admin_pass" 2>&1)

  # Check if domain creation succeeded
  if [[ "$create_output" == *"SUCCESS"* ]]; then
    subscription_id=$(plesk bin subscription --list | grep -E "$domain" | awk '{print $1}')

    if [ -n "$subscription_id" ]; then
      # Download wp-config-sample.php
      wp core download --path="/var/www/vhosts/$domain/httpdocs/" --allow-root | tee -a credentials.txt

      # Updated to avoid tee after redirection
      sed -e "s#localhost#$db_host#; s#database_name_here#$db_name#; s#username_here#$db_user#; s#password_here#$db_password#" \
      /var/www/vhosts/"$domain"/httpdocs/wp-config-sample.php > /var/www/vhosts/"$domain"/httpdocs/wp-config.php
      echo "Configured wp-config.php for $domain" | tee -a credentials.txt

      # Install WordPress
      wp core install --path="/var/www/vhosts/$domain/httpdocs/" --url="https://$domain" --title="$title" --admin_user="$admin_user" --admin_password="$admin_pass" --admin_email="$email" --allow-root | tee -a credentials.txt

      # Function to generate randomized URL structure:
      random_url_structure() {
       local structures=(
         "/%category%/%postname%/"
         "/%year%/%monthnum%/%postname%/"
         "/%author%/%postname%/"
         "/%post_id%/%postname%/"
         "/%year%/%postname%/"
         "/%monthnum%/%day%/%postname%/"
         "/%category%/%year%/%postname%/"
    #     "/%tag%/%postname%/"
         "/%postname%/"
    #     "/%year%/%monthnum%/%day%/%hour%/%postname%/"
         "/%category%/%post_id%/"
         "/%author%/%year%/%post_id%/"
    #     "/%tag%/%post_id%/"
       )
       echo "${structures[RANDOM % ${#structures[@]}]}"
      }

      url_structure=$(random_url_structure)
      wp rewrite structure "$url_structure" --path="/var/www/vhosts/$domain/httpdocs/" --allow-root
      #wp rewrite flush --path="/var/www/vhosts/$domain/httpdocs/" --allow-root
      #wp option get permalink_structure --path="/var/www/vhosts/$domain/httpdocs/" --allow-root

      # Initialize SSL installation retry counter
      ssl_retries=0
      ssl_install_success=false

      # Attempt SSL installation with retries
      while [[ $ssl_retries -lt $max_retries && $ssl_install_success == false ]]; do
        # Install SSL certificate on www and non-www domain
        if plesk bin extension --exec letsencrypt cli.php -d "$domain" -d "www.$domain" -m "$ssl_email" >> "$letsencrypt_log" 2>&1; then
          # Increment the counter for successful SSL installations
          ssl_install_count=$((ssl_install_count + 1))
          
          echo "SSL successfully installed for $domain and www.$domain" | tee -a "$letsencrypt_log"
          ssl_install_success=true
          echo ""
        else
          # Log the failure and retry
          ssl_retries=$((ssl_retries + 1))
          echo "Attempt $ssl_retries of $max_retries failed for $domain and www.$domain" | tee -a "$letsencrypt_log"
          echo "Retrying..." | tee -a "$letsencrypt_log"
          
          # Restart services if retrying
          systemctl restart apache2
          systemctl restart nginx
        fi
      done

      # If SSL installation fails after all retries
      if [ $ssl_install_success == false ]; then
        echo "FAILED TO INSTALL SSL FOR $domain after $max_retries attempts" | tee -a "$letsencrypt_log"
        echo ""
      fi

      # Check if SSL installation count reached 100
      if [[ $ssl_install_count -ge 100 ]]; then
        echo "Reached 100 SSL installations. Restarting Apache and Nginx services..." | tee -a "$letsencrypt_log"

        # Reset Apache and Nginx services
        systemctl restart apache2
        systemctl restart nginx

        # Reset the counter
        ssl_install_count=0
      fi

      # Update file ownership
      chown -R $admin_user: /var/www/vhosts/$domain/httpdocs/
      chown $admin_user:psaserv /var/www/vhosts/$domain/httpdocs/
      
      # Remove index.html
      rm -f /var/www/vhosts/$domain/httpdocs/index.html

      # Print out info and save to credentials.txt
      {
        echo "---------------------------------------------------"
        echo "Website and WordPress installed for $domain"
        echo "File ownership updated to $admin_user"
        echo "Admin Username: $admin_user"
        echo "Admin Password: $admin_pass"
        echo "Admin Email: $email"
        echo "Admin Login: $domain/wp-login.php"
        echo -e "---------------------------------------------------\n"
      } >> credentials.txt
    else
      echo "Failed to retrieve subscription ID for $domain" | tee -a credentials.txt
    fi
  else
    echo -e "An error occurred during domain creation for $domain: $create_output\n" | tee -a credentials.txt
  fi
done
