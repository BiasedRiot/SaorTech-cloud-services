#!/bin/bash

# This script is used to set up a test website/portfolio under apache. The script takes in- 
# a domain as a CLI flag and sets up the apache config + the SSL cert for it.
# Once the script is finished you can replace the template html file with your own files. 

TEMP=`getopt -o d: --long domain: -- "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -d|--domain)
            my_domain=$2 ; shift 2;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

# Installing and updating dependancies
echo "Setting up Apache"
apt update -y
apt install apache2 -y
systemctl start apache2
systemctl enable apache2


echo "Setting up encryption"
apt install certbot -y
apt install python3-certbot-apache -y

apache_conf="$my_domain.conf"
touch /etc/apache2/sites-available/$apache_conf

echo "
<VirtualHost *:80>
        ServerName $my_domain

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/$my_domain


        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
" >> /etc/apache2/sites-available/$apache_conf

cp /etc/apache2/sites-available/$apache_conf /etc/apache2/sites-enabled/$apache_conf
systemctl restart apache2

# Creating a certbot SSL certificate for the domain
(sleep 2
echo 2
sleep 2) | sudo certbot --apache -d $my_domain --redirect


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
" >> /etc/apache2/sites-enabled/$apache_conf

mkdir /var/www/$my_domain
echo "
<html>
<head><title>Get gud fgt</title></head>
<body>
  <center>
    <h1>Lol learn 2 code noob</h1>
  </center>
</body>
</html>
" >> /var/www/$my_domain/index.html

systemctl restart apache2

