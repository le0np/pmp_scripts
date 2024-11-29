#!/bin/bash
#
# DESCRIPTION: 
# This script reads domain names from the 'domains.txt' file, attempting to install a default WordPress website for each domain.
# It has been tested on Ubuntu 20.04.6 LTS with Plesk Obsidian 18.0.57.5.
#
# The script checks for the presence of 'wp-cli' and 'php-mysql', installs them if needed, and proceeds to create WordPress websites.
# For each domain, it generates a random admin username, database name, and user, then creates the necessary MySQL database and user.
# Subsequently, it creates a Plesk subscription, downloads WordPress, configures wp-config.php, and installs WordPress.
# File ownership and permissions are updated, and information about the installation is displayed.
#
# NOTE: This script assumes that 'wp-cli' and 'php-mysql' are not already installed, and it uses 'domains.txt' for domain names.
# Adjustments may be needed based on specific server configurations and requirements.
#
# AUTHOR: le0np
# DATE: 30/04/2024

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
> "$letsencrypt_log"

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
  admin_pass=$(tr -dc 'A-Za-z0-9!#$%&()*-<>?@^_~' < /dev/urandom | head -c 16)
  title="${domain%%.*}"
  email="info@$domain"
  service_plan="Default Domain"
  create_output=$(plesk bin subscription --create $domain -service-plan "$service_plan" -ip "$ip" -login "$admin_user" -passwd "$admin_pass" 2>&1)
  # theme= DOPUNI OVO

  # Check if domain creation succeeded
  if [[ "$create_output" == *"SUCCESS"* ]]; then
    subscription_id=$(plesk bin subscription --list | grep -E "$domain" | awk '{print $1}')

    if [ -n "$subscription_id" ]; then
      # Download wp-config-sample.php
      wp core download --path="/var/www/vhosts/$domain/httpdocs/" --allow-root | tee -a credentials.txt

      sed -e 's#localhost#'"$db_host"'#; s#database_name_here#'"$db_name"'#; s#username_here#'"$db_user"'#; s#password_here#'"$db_password"'#;' /var/www/vhosts/"$domain"/httpdocs/wp-config-sample.php > /var/www/vhosts/"$domain"/httpdocs/wp-config.php | tee -a credentials.txt

      # Install WordPress
      wp core install --path="/var/www/vhosts/$domain/httpdocs/" --url="https://$domain" --title="$title" --admin_user="$admin_user" --admin_password="$admin_pass" --admin_email="$email" --allow-root | tee -a credentials.txt

      # Install the theme (replace 'theme-slug' with the actual slug of the theme)
      #wp theme install $theme --path="/var/www/vhosts/$domain/httpdocs/" --activate --allow-root

      # Install SSL certificate on www and non-www domain
      if plesk bin extension --exec letsencrypt cli.php -d "$domain" -d "www.$domain" -m "$ssl_email" >> "$letsencrypt_log" 2>&1; then
        echo "SSL successfully installed for $domain and www.$domain" | tee -a "$letsencrypt_log"
      else
        echo "FAILED TO INSTALL SSL FOR $domain and www.$domain" | tee -a "$letsencrypt_log"
      fi
      
      # Update file ownership
      chown -R $admin_user: /var/www/vhosts/$domain/httpdocs/
      chown $admin_user:psaserv /var/www/vhosts/$domain/httpdocs/
      
      # Remove index.html
      rm -f /var/www/vhosts/$domain/httpdocs/index.html

      # Print out info and save to credentials.txt
      echo "---------------------------------------------------" >> credentials.txt
      echo "Website and WordPress installed for $domain" >> credentials.txt
      echo "File ownership updated to $admin_user" >> credentials.txt
      echo "Admin Username: $admin_user" >> credentials.txt
      echo "Admin Password: $admin_pass" >> credentials.txt
      echo "Admin Email: $email" >> credentials.txt
      echo "Admin Login: $domain/wp-login.php" >> credentials.txt
      echo -e "---------------------------------------------------\n" >> credentials.txt
    else
      echo "Failed to retrieve subscription ID for $domain" | tee -a credentials.txt
    fi
  else
    echo -e "An error occurred during domain creation for $domain: $create_output\n" | tee -a credentials.txt
  fi
done
