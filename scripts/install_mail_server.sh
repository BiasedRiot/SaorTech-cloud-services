##!/bin/bash

my_domain="example.com"
FQDN="mail.example.com"

my_password="SETAGOODPASSWORDFORFECKSAKE"

user1="eoin"

# It is good to have multiple emails for compartmentalising your -
# online activity. For example an email for social media, buying stuff online -
# and a third for professional stuff.
alias1="social"
alias2="purchasing"
alias3="primary"

email1="${user1}@${my_domain}"

alias_email1="${alias1}@${my_domain}"
alias_email2="${alias2}@${my_domain}"
alias_email3="${alias3}@${my_domain}"

# Installing Postfix
echo "Installing requirements"
apt update
debconf-set-selections <<< "postfix postfix/mailname string $my_domain"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

apt install postfix postfix-mysql dovecot-core dovecot-imapd dovecot-lmtpd dovecot-pop3d dovecot-mysql spamassassin spamc -y
#Setting up Encryption
echo "Setting up encryption"
apt install certbot -y

service apache2 stop

(sleep 2
echo $email1
sleep 2
echo "A") | sudo certbot --standalone -d $FQDN --redirect

service apache2 restart

# Create DB
echo "Creating DB"
(sleep 2
echo "CREATE DATABASE servermail;"
sleep 2
echo "GRANT SELECT ON servermail.* TO 'usermail'@'127.0.0.1' IDENTIFIED BY 'mailpassword';"
sleep 2
echo "FLUSH PRIVILEGES;") | mariadb


# Create tables
echo "Creating tables"
(sleep 2
echo "USE servermail;"
sleep 2
echo "CREATE TABLE virtual_domains (id  INT NOT NULL AUTO_INCREMENT,
name VARCHAR(50) NOT NULL, PRIMARY KEY (id) ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
sleep 2
echo "CREATE TABLE virtual_users (id INT NOT NULL AUTO_INCREMENT, domain_id INT NOT NULL,
password VARCHAR(106) NOT NULL, email VARCHAR(120) NOT NULL, PRIMARY KEY (id),
UNIQUE KEY email (email), FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
sleep 2
echo "
CREATE TABLE virtual_aliases (id INT NOT NULL AUTO_INCREMENT, domain_id INT NOT NULL,
source varchar(100) NOT NULL, destination varchar(100) NOT NULL, PRIMARY KEY (id),
FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;") | mariadb

#Adding in Data
echo "Adding data to tables"
(sleep 2
echo "INSERT INTO servermail.virtual_domains (id , name)
VALUES ('1', '$my_domain'), ('2', '$FQDN');"
sleep 2
echo "
INSERT INTO servermail.virtual_users (id, domain_id, password , email)
VALUES ('1', '1', ENCRYPT('$my_password'), '$email1');"
sleep 2
echo "
INSERT INTO servermail.virtual_aliases (id, domain_id, source, destination)
VALUES ('1', '1', '$alias_email1', '$email1'),
('2', '1', '$alias_email2', '$email1'),
('3', '1', '$alias_email3', '$email1');" | mariadb

# Configure Postfix
echo "Configuring Postfix"
cp /etc/postfix/main.cf /etc/postfix/main.cf.orig

#Configure TLS
postconf -e "smtpd_tls_cert_file=/etc/letsencrypt/live/$FQDN/fullchain.pem"
postconf -e "smtpd_tls_key_file=/etc/letsencrypt/live/$FQDN/privkey.pem"
postconf -e 'ssmtpd_use_tls=yes'
postconf -e 'smtpd_tls_auth_only = yes'

#Configure SMTP
postconf -e 'smtpd_sasl_type = dovecot'
postconf -e 'smtpd_sasl_path = private/auth'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_recipient_restrictions =
permit_sasl_authenticated,
permit_mynetworks,
reject_unauth_destination'

#Enable Localhost for SQL table
postconf -e 'mydestination = localhost'

postconf -e "myhostname = $FQDN"

#Configure Virtual Domains
postconf -e 'virtual_transport = lmtp:unix:private/dovecot-alias_email1lmtp'
postconf -e 'virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf'
postconf -e 'virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf'
postconf -e 'virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf'


#Create domain config file
echo "user = usermail
password = mailpassword
hosts = 127.0.0.1
dbname = servermail
query = SELECT 1 FROM virtual_domains WHERE name='%s'" > /etc/postfix/mysql-virtual-mailbox-domains.cf

service postfix restart

# Testing domain
postmap -q $my_domain mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf

if [ $? -eq 1 ]; then
   echo "FAILED: Domain check unsuccessfull"
fi

# Adding emails
echo "user = usermail
password = mailpassword
hosts = 127.0.0.1
dbname = servermail
query = SELECT 1 FROM virtual_users WHERE email='%s'" > /etc/postfix/mysql-virtual-mailbox-maps.cf 

# Adding aliases
echo "user = usermail
password = mailpassword
hosts = 127.0.0.1
dbname = servermail
query = SELECT destination FROM virtual_aliases WHERE source='%s'" > /etc/postfix/mysql-virtual-alias-maps.cf

service postfix restart

echo "
submission inet n       -       -       -       -       smtpd
-o syslog_name=postfix/submission
-o smtpd_tls_security_level=encrypt
-o smtpd_sasl_auth_enable=yes
-o smtpd_client_restrictions=permit_sasl_authenticated,reject
-o content_filter=spamassassin"  > /etc/postfix/master.cf
service postfix restart

# Configure Dovecot
cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.orig
cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.orig
cp /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.orig
cp /etc/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext.orig
cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.orig
cp /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.orig


sed -i "s?#!include conf.d/*.conf?!include conf.d/*.conf?" /etc/dovecot/dovecot.conf

sed -i "25i protocols = imap lmtp pop3" /etc/dovecot/dovecot.conf

sed -i "s/mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/mail_location = maildir:\/var\/mail\/vhosts\/%d\/%n/" /etc/dovecot/conf.d/10-mail.conf
sed -i "s/#mail_privileged_group = mail/mail_privileged_group = mail/" /etc/dovecot/conf.d/10-mail.conf

#Housekeeping
mkdir -p /var/mail/vhosts/$my_domain
groupadd -g 5000 vmail 
useradd -g vmail -u 5000 vmail -d /var/mail
chown -R vmail:vmail /var/mail


echo "disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-sql.conf.ext
" > /etc/dovecot/conf.d/10-auth.conf

#Create conf file
echo "passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}
userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n
} " > /etc/dovecot/conf.d/auth-sql.conf.ext


# Modify mysql
sed -i "s/#driver = /driver = mysql/" /etc/dovecot/dovecot-sql.conf.ext
sed -i "s/#connect =/connect = host=127.0.0.1 dbname=servermail user=usermail password=mailpassword/" /etc/dovecot/dovecot-sql.conf.ext
sed -i "s/#default_pass_scheme = MD5/default_pass_scheme = SHA512-CRYPT/" /etc/dovecot/dovecot-sql.conf.ext
echo "password_query = SELECT email as user, password FROM virtual_users WHERE email='%u';" >> /etc/dovecot/dovecot-sql.conf.ext
chown -R vmail:dovecot /etc/dovecot
chmod -R o-rwx /etc/dovecot 



echo "
service imap-login {
  inet_listener imap {
    port = 0
  }
  inet_listener imaps {

  }

}
service pop3-login {
  inet_listener pop3 {

  }
  inet_listener pop3s {

  }
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
   mode = 0600
   user = postfix
   group = postfix
  }

}

service imap {

}

service pop3 {

}

service auth {

  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }

  unix_listener auth-userdb {
   mode = 0600
   user = vmail
  }

  user = dovecot
}

service auth-worker {
  user = vmail
}

service dict {

  unix_listener dict {

  }
}" > /etc/dovecot/conf.d/10-master.conf

# Enable SSL
sed -i "s/ssl = yes/ssl = required/" /etc/dovecot/conf.d/10-ssl.conf
sed -i "s%ssl_cert = </etc/ssl/certs/dovecot.pem%ssl_cert = smtpd_tls_cert_file=/etc/letsencrypt/live/$FQDN/fullchain.pem%" /etc/dovecot/conf.d/10-ssl.conf
sed -i "s%ssl_key = </etc/ssl/private/dovecot.pem%smtpd_tls_key_file=/etc/letsencrypt/live/$FQDN/privkey.pem%" /etc/dovecot/conf.d/10-ssl.conf

service dovecot restart


# Setting Up Spam Assassin
(sleep 2
echo $user1) | adduser spamd --disabled-login


sudo update-rc.d spamassassin enable

sed -i 's/OPTIONS="--create-prefs --max-children 5 --helper-home-dir"/OPTIONS="--create-prefs --max-children 5 --username spamd --helper-home-dir ${SPAMD_HOME} -s ${SPAMD_HOME}spamd.log"/' /etc/default/spamassassin

echo 'ENABLES=1
SPAMD_HOME="/home/spamd/"
OPTIONS="--create-prefs --max-children 5 --username spamd --helper-home-dir ${SPAMD_HOME} -s ${SPAMD_HOME}spamd.log"
PIDFILE="${SPAMD_HOME}spamd.pid"
CRON=1' > /etc/default/spamassassin

echo "rewrite_header Subject ***** SPAM _SCORE_ *****
report_safe             0
required_score          5.0
use_bayes               1
use_bayes_rules         1
bayes_auto_learn        1
skip_rbl_checks         0
use_razor2              0
use_dcc                 0
use_pyzor               0
" > /etc/spamassassin/local.cf

service spamassassin start
service postfix restart


# OpenDKIM setup
apt install opendkim opendkim-tools -y
opendkim opendkim-genkey -D /etc/dkimkeys -d $FQDN -s 2020

sed -i "s/#Domain                 example.com/Domain    $my_domain/" /etc/opendkim.conf
sed -i "s/#Selector               2007/Selector 2020/" /etc/opendkim.conf
sed -i "s/Socket                  local:\/run\/opendkim\/opendkim.sock/Socket   inet:8891@localhost/" /etc/opendkim.conf
sed -i "s/#KeyFile                \/etc\/dkimkeys\/dkim.key/KeyFile  \/etc\/dkimkeys\/2020.private/" /etc/opendkim.conf
service opendkim restart
postconf -e "smtpd_milters = inet:localhost:8891"
postconf -e 'non_smtpd_milters = $smtpd_milters'
service opendkim reload


echo "Congrats the script is finised. Make sure that neccessary ports are open so you can send mail!"





