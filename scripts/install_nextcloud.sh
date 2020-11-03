#!/bin/bash

my_domain="nextcloud.example.com"
# Used for SSL certificates. Don't worry they wont send you any news or -
# annoying stuff it's specified when running the certbot command.
my_email="test@protonmail.com" 

echo "Starting Installation"

# Installing Apache2
echo "Setting up Apache"
apt install apache2 -y
systemctl start apache2
systemctl enable apache2


# Installing MariaDB for the storage
echo "Setting up the DB"
echo "ATTENTION: THE REPOSITORY USED FOR THE MARIADB PACKAGE IS FOR UBUNTU 20"
apt-get install software-properties-common
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mariadb.mirror.iweb.com/repo/10.5/ubuntu focal main' -y
apt install mariadb-server -y

(sleep 2
echo ""
sleep 2
echo "n"
sleep 2
echo "y"
sleep 2
echo "y"
sleep 2
echo "y"
sleep 2
echo "y"
) | mysql_secure_installation 

(echo "") | add-apt-repository ppa:ondrej/php
apt install php7.3 libapache2-mod-php7.3 php7.3-mysql -y

(sleep 2
echo "CREATE DATABASE nextcloud;"
sleep 2
echo "CREATE USER nextcloud IDENTIFIED BY 'Password';"
sleep 2
echo "GRANT USAGE ON *.* TO 'nextcloud'@'localhost' IDENTIFIED BY 'Password';"
sleep 2
echo "GRANT ALL privileges ON nextcloud.* TO 'nextcloud'@'localhost';"
sleep 2
echo "FLUSH PRIVILEGES;"
) | mariadb 

echo "Database has been created. User=nextcloud, Password=Password, DatabaseName=nextcloud"

# Installing Nextcloud
echo "Setting up nextcloud"
apt install php7.3-gd php7.3-json php7.3-mysql php7.3-curl php7.3-mbstring php7.3-intl php7.3-imagick php7.3-xml php7.3-zip -y

wget https://download.nextcloud.com/server/releases/nextcloud-15.0.7.tar.bz2
tar -xvf nextcloud-15.0.7.tar.bz2
cd nextcloud
rm /var/www/html/index.html
mv ./* /var/www/html/ | mv ./.htaccess /var/www/html | mv ./.user.ini /var/www/html


cd /var/www/html
rm -r ~/nextcloud/
chown -R www-data:www-data ./*
chown www-data:www-data .htaccess
chown www-data:www-data .user.ini


#Setting up Encryption
echo "Setting up encryption"
apt install certbot -y
apt install python3-certbot-apache -y

sed -i "s/#ServerName www.example.com/ServerName $my_domain/" /etc/apache2/sites-available/000-default.conf

cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/000-default.conf
systemctl restart apache2

(sleep 2
echo $my_email
sleep 2
echo "A") | sudo certbot --apache -d $my_domain --redirect



# Creating data directory in root directory 
# This is needed as having the data directory inside the apache folder may make files vulnerable as 
# location is accessable from browser.
echo "Creating data directory for storage"
echo " MAKE SURE YOU SPECIFY /nextcloud-data WHEN SETTING UP ADMIN ACCOUNT IN BROWSER"

mkdir /nextcloud-data
chown www-data:www-data /nextcloud-data
chown www-data:www-data /nextcloud-data/


# Housekeeping (security best practices)
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 512M/" /etc/php/7.3/apache2/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.3/apache2/php.ini
sed -i "s/post_max_size = 8M/post_max_size = 512M/" /etc/php/7.3/apache2/php.ini
systemctl restart apache2

#Enabling HSTS and other security settings
echo "
<IfModule mod_ssl.c>
<VirtualHost *:443>
        ServerName $my_domain
        <IfModule mod_headers.c>
          Header always set Strict-Transport-Security \"max-age=15552000; includeSubDomains; preload\"
        </IfModule>

	<Directory /var/www/html/>
		Options +FollowSymlinks
		AllowOverride All
	</Directory>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html


        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined


ServerAlias $my_domain
SSLCertificateFile /etc/letsencrypt/live/$my_domain/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/$my_domain/privkey.pem
Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
" > /etc/apache2/sites-enabled/000-default-le-ssl.conf

sed -i "s/;opcache.enable=1/opcache.enable=1/" /etc/php/7.3/apache2/php.ini 
sed -i "s/;opcache.enable_cli=0/opcache.enable_cli=1/" /etc/php/7.3/apache2/php.ini 
sed -i "s/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=8/" /etc/php/7.3/apache2/php.ini 
sed -i "s/;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=10000/" /etc/php/7.3/apache2/php.ini 
sed -i "s/;opcache.memory_consumption=128/opcache.memory_consumption=128/" /etc/php/7.3/apache2/php.ini 
sed -i "s/;opcache.save_comments=1/opcache.save_comments=1/" /etc/php/7.3/apache2/php.ini 
sed -i "s/;opcache.revalidate_freq=2/opcache.revalidate_freq=1/" /etc/php/7.3/apache2/php.ini 

systemctl restart apache2
a2enmod headers

-u www-data php /var/www/html/./occ db:convert-filecache-bigint

echo "Congradulations nextcloud is officially set up "
