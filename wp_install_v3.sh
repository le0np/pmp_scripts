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
         "/%postname%/"
         "/%category%/%post_id%/"
         "/%author%/%year%/%post_id%/"
       )
       echo "${structures[RANDOM % ${#structures[@]}]}"
      }
      
# Function to generate a valid password
generate_password() {
    local admin_pass special_char_count
    while true; do
        # Generate a password with the specified character set
        admin_pass=$(tr -dc 'A-Za-z0-9!#$%&()*-<>?@^_~' < /dev/urandom | head -c 16)
        
        # Count the number of special characters
        special_char_count=$(echo "$admin_pass" | grep -o '[!#$%&()*-<>?@^_~]' | wc -l)
        
        # Ensure the first character is not a special character and special characters are limited to 2-3
        if [[ ${admin_pass:0:1} =~ [A-Za-z0-9] && $special_char_count -ge 2 && $special_char_count -le 4 ]]; then
            echo "$admin_pass"
            return
        fi
    done
}

# Update packages 
apt update -y && apt upgrade -y

#!/bin/bash

# Check if PHP-CLI is already installed
if command -v php &> /dev/null; then
    echo -e "PHP-CLI is already installed.\n"
else
    echo "Select the version of PHP-CLI to install:"
    echo "1) php-8.0-cli"
    echo "2) php-8.1-cli"
    echo "3) php-8.2-cli"
    echo "4) php-8.3-cli"
    echo "5) php-8.4-cli"
    
    # Read user input
    read -p "Enter the number of the PHP version to install (1-5): " php_choice

    # Install requirements and add repository
    apt install software-properties-common -y
    add-apt-repository ppa:ondrej/php -y
    apt update

    # Install chosen PHP-CLI version
    case "$php_choice" in
        1)
            echo "Installing php-8.0-cli..."
            apt install php8.0-cli -y | tee -a credentials.txt
            ;;
        2)
            echo "Installing php-8.1-cli..."
            apt install php8.1-cli -y | tee -a credentials.txt
            ;;
        3)
            echo "Installing php-8.2-cli..."
            apt install php8.2-cli -y | tee -a credentials.txt
            ;;
        4)
            echo "Installing php-8.3-cli..."
            apt install php8.3-cli -y | tee -a credentials.txt
            ;;
        5)
            echo "Installing php-8.4-cli..."
            apt install php8.4-cli -y | tee -a credentials.txt
            ;;
        *)
            echo "Invalid selection. Please select a number between 1 and 5."
            ;;
    esac
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

#SSL configurations
read -p "Enter email for SSL install: " ssl_email

# Create or clear the credentials.txt file and letsencrypt log file
> credentials.txt
> "$letsencrypt_log"  # Corrected to use the variable and ensure the file is created

# Maximum number of retries for SSL installation
max_retries=3

# URL structure to use
url_structure=$(random_url_structure)
echo "URL structure to use is: $url_structure"

# Loop through each domain
for domain in $(cat "$domains"); do
  # Generate random string for the admin username
  random_string=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)  # Adjust the length as needed
  random_string2=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 10) # Adjust the length as needed

  # Generate database name and user
  db_name="$random_string"
  db_user="$random_string2"
  db_password=$(openssl rand -base64 25 | head -c 20)
  db_host="localhost:3306"

  # Create website subscription
  admin_user="pmp_admin_$random_string"
  
  # Generate a valid admin password using the function along with some other variables
  admin_pass=$(generate_password)
  title="${domain%%.*}"
  email="info@$domain"
  service_plan="Default Domain"
  create_output=$(plesk bin subscription --create $domain -service-plan "$service_plan" -ip "$ip" -login "$admin_user" -passwd "$admin_pass" 2>&1)

  # Use Plesk command to create the database and user, and associate them with the domain
  plesk bin database --create "$db_name" -domain "$domain" -type mysql
  plesk bin database --create-dbuser "$db_user" -passwd "$db_password" -domain "$domain" -server "$db_host" -database "$db_name"
  plesk bin database --assign-to-subscription "$db_name" -domain "$domain" -server "$db_host"

  
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
  
      wp rewrite structure "$url_structure" --path="/var/www/vhosts/$domain/httpdocs/" --allow-root
      wp rewrite flush --path="/var/www/vhosts/$domain/httpdocs/" --allow-root
      #wp option get permalink_structure --path="/var/www/vhosts/$domain/httpdocs/" --allow-root # Testing to see if correct structure is applied
      wp config shuffle-salts --path="/var/www/vhosts/$domain/httpdocs/" --allow-root  # Shuffle keys in wp-config.php
    
      # Creating .htaccess files for domain
      htaccess_file="/var/www/vhosts/$domain/httpdocs/.htaccess"
      if [ ! -f "$htaccess_file" ]; then
        cat > "$htaccess_file" <<EOL
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOL
        echo ".htaccess file created at /var/www/vhosts/$domain/httpdocs/"
      else
        echo ".htaccess file already exists at /var/www/vhosts/$domain/httpdocs/"
      fi
      
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
          # Enable option to keep website secure with SSL 
          plesk bin subscription --add-custom-plan-item $domain -custom-plan-item-name "urn:ext:sslit:plan-item-sdk:keep-secured"
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

# Remove stuff installed for expireds
apt remove --purge php-cli php8.*-cli -y
apt autoremove -y
add-apt-repository --remove ppa:ondrej/php -y
apt update
rm -f /usr/local/bin/wp
