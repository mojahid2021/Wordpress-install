#!/bin/bash

# Function to generate random password
generate_password() {
    openssl rand -base64 12
}

# Ask for domain or use IP
read -p "Enter your domain name (or leave blank to use server IP): " DOMAIN

# Set variables
DB_NAME=wordpress
DB_USER=wp_user
DB_PASS=$(generate_password)
WP_DIR=/var/www/html

echo "Updating system..."
apt update && apt upgrade -y

echo "Installing necessary packages..."
apt install apache2 mariadb-server php php-mysql libapache2-mod-php php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip wget curl unzip -y

echo "Starting Apache and MariaDB..."
systemctl enable apache2 mariadb
systemctl start apache2 mariadb

echo "Securing MariaDB..."
mysql_secure_installation

echo "Creating WordPress database and user..."
mysql -u root <<EOF
CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "Downloading WordPress..."
cd /tmp
wget https://wordpress.org/latest.zip
unzip latest.zip
rm -rf $WP_DIR/*
cp -r wordpress/* $WP_DIR
chown -R www-data:www-data $WP_DIR
chmod -R 755 $WP_DIR

echo "Configuring wp-config.php..."
cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" $WP_DIR/wp-config.php
sed -i "s/username_here/$DB_USER/" $WP_DIR/wp-config.php
sed -i "s/password_here/$DB_PASS/" $WP_DIR/wp-config.php

# Add security keys
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
sed -i "/AUTH_KEY/d" $WP_DIR/wp-config.php
echo "$SALT" >> $WP_DIR/wp-config.php

echo "Restarting Apache..."
systemctl restart apache2

echo "Allowing HTTP and HTTPS through UFW..."
ufw allow 'Apache Full'
ufw enable

echo "Done!"
echo "WordPress installed at: http://${DOMAIN:-your-server-ip}/"
echo "Database: $DB_NAME"
echo "DB User: $DB_USER"
echo "DB Password: $DB_PASS"
