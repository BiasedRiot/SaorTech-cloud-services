#!/bin/bash

# It is good to have multiple emails for compartmentalising your -
# online activity. For example an email for social media, buying stuff online -
# and a third for professional stuff.
alias1="social"
alias2="purchasing"
alias3="primary"


# CLI Arguments (Specify -e email, -u user, -p password or -d domain )
TEMP=`getopt -o f:u:e:d:p: --long fqdn:,user:,email:,domain:,password:, -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -e|--email)
            my_email=$2 ; shift 2 ;;
        -p|--password)
            my_password=$2 ; shift 2 ;;
        -u|--user)
            user1=$2 ; shift 2 ;;
        -d|--domain)
            my_domain=$2 ; shift 2;;
        -f|--fqdn)
            FQDN=$2 ; shift 2;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

email1="${user1}@${my_domain}"

alias_email1="${alias1}@${my_domain}"
alias_email2="${alias2}@${my_domain}"
alias_email3="${alias3}@${my_domain}"

# Installing Postfix
echo "Installing requirements"
apt update -y
debconf-set-selections <<< "postfix postfix/mailname string $my_domain"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

apt install apache2 postfix postfix-mysql dovecot-core dovecot-imapd dovecot-lmtpd dovecot-pop3d dovecot-mysql spamassassin spamc -y

#Setting up Encryption
echo "Setting up encryption"
apt install certbot -y
service apache2 stop
certbot certonly --standalone -d $my_domain --redirect
service apache2 restart

# Create DB
echo "Creating DB"
(sleep 2
echo "CREATE DATABASE usermail;"
sleep 2
echo "GRANT SELECT ON usermail.* TO 'usermail'@'127.0.0.1' IDENTIFIED BY '$my_password';"
sleep 2
echo "FLUSH PRIVILEGES;") | mariadb


# Create tables
echo "Creating tables"
(sleep 2
echo "USE usermail;"
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
echo "INSERT INTO usermail.virtual_domains (id , name)
VALUES ('1', '$my_domain');"
sleep 2
echo "
INSERT INTO usermail.virtual_users (id, domain_id, password , email)
VALUES ('1', '1', ENCRYPT('$my_password'), '$email1');"
sleep 2
echo "
INSERT INTO usermail.virtual_aliases (id, domain_id, source, destination)
VALUES ('1', '1', '$alias_email1', '$email1'),
('2', '1', '$alias_email2', '$email1'),
('3', '1', '$alias_email3', '$email1');") | mariadb

# Configure Postfix
echo "Configuring Postfix"
cp /etc/postfix/main.cf /etc/postfix/main.cf.orig

#Configure TLS
postconf -e "smtpd_tls_cert_file=/etc/letsencrypt/live/$my_domain/fullchain.pem"
postconf -e "smtpd_tls_key_file=/etc/letsencrypt/live/$my_domain/privkey.pem"
postconf -e 'ssmtpd_use_tls=yes'
postconf -e 'smtpd_tls_auth_only = yes'

#Configure SMTP
postconf -e 'smtpd_sasl_type = dovecot'
postconf -e 'smtpd_sasl_path = private/auth'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtp_tls_security_level = may'
postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination'

#Enable Localhost for SQL table
postconf -e 'mydestination = localhost'

postconf -e "myhostname = vps1.$my_domain"

#Configure Virtual Domains
postconf -e 'virtual_transport = lmtp:unix:private/dovecot-alias_email1lmtp'
postconf -e 'virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf'
postconf -e 'virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf'
postconf -e 'virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf'


#Create domain config file
echo "user = usermail
password = $my_password
hosts = 127.0.0.1
dbname = usermail
query = SELECT 1 FROM virtual_domains WHERE name='%s'" > /etc/postfix/mysql-virtual-mailbox-domains.cf

service postfix restart

# Testing domain
postmap -q $my_domain mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf

if [ $? -eq 1 ]; then
   echo "FAILED: Domain check unsuccessfull"
fi

# Adding emails
echo "user = usermail
password = $my_password
hosts = 127.0.0.1
dbname = usermail
query = SELECT 1 FROM virtual_users WHERE email='%s'" > /etc/postfix/mysql-virtual-mailbox-maps.cf 

# Adding aliases
echo "user = usermail
password = $my_password
hosts = 127.0.0.1
dbname = usermail
query = SELECT destination FROM virtual_aliases WHERE source='%s'" > /etc/postfix/mysql-virtual-alias-maps.cf

service postfix restart

echo '
smtp      inet  n       -       y       -       -       smtpd
  -o content_filter=spamassassin
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

pickup    unix  n       -       y       60      1       pickup
cleanup   unix  n       -       y       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
#qmgr     unix  n       -       n       300     1       oqmgr
tlsmgr    unix  -       -       y       1000?   1       tlsmgr
rewrite   unix  -       -       y       -       -       trivial-rewrite
bounce    unix  -       -       y       -       0       bounce
defer     unix  -       -       y       -       0       bounce
trace     unix  -       -       y       -       0       bounce
verify    unix  -       -       y       -       1       verify
flush     unix  n       -       y       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       y       -       -       smtp
relay     unix  -       -       y       -       -       smtp
        -o syslog_name=postfix/$service_name
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       y       -       -       showq
error     unix  -       -       y       -       -       error
retry     unix  -       -       y       -       -       error
discard   unix  -       -       y       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       y       -       -       lmtp
anvil     unix  -       -       y       -       1       anvil
scache    unix  -       -       y       -       1       scache
postlog   unix-dgram n  -       n       -       1       postlogd

maildrop  unix  -       n       n       -       -       pipe
  flags=DRhu user=vmail argv=/usr/bin/maildrop -d ${recipient}
uucp      unix  -       n       n       -       -       pipe
  flags=Fqhu user=uucp argv=uux -r -n -z -a$sender - $nexthop!rmail ($recipient)
ifmail    unix  -       n       n       -       -       pipe
  flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r $nexthop ($recipient)
bsmtp     unix  -       n       n       -       -       pipe
  flags=Fq. user=bsmtp argv=/usr/lib/bsmtp/bsmtp -t$nexthop -f$sender $recipient
scalemail-backend unix  -       n       n       -       2       pipe
  flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store ${nexthop} ${user} ${extension}
mailman   unix  -       n       n       -       -       pipe
  flags=FR user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py
  ${nexthop} ${user}
spamassassin unix -     n       n       -       -       pipe
  user=spamd argv=/usr/bin/spamc -f -e
  /usr/sbin/sendmail -oi -f ${sender} ${recipient}
' > /etc/postfix/master.cf
service postfix restart

# Configure Dovecot
cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.orig
cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.orig
cp /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.orig
cp /etc/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext.orig
cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.orig
cp /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.orig


echo "ssl_cert = </etc/letsencrypt/live/$my_domain/fullchain.pem
ssl_key = </etc/letsencrypt/live/$my_domain//privkey.pem

mail_location = maildit:/home/$user1/mail/%d/%n
mail_privileged_group = $user1

passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}

userdb {
  driver = static
  args = uid=$user1 gid=$user1 home=/home/$user1/mail/%d/%n
}
" > /etc/dovecot/dovecot.conf

#Housekeeping
mkdir /home/$user1/mail
mkdir /home/$user1/mail/$my_domain
groupadd -g 5000 $user1 
useradd -g $user1 -u 5000 $user1 -d /home/$user1/mail
chown -R $user1:$user1 /home/$user1/mail

# Modify mysql
echo "
driver = mariadb
connect = host=localhost dbname=mail user=mail password=$my_password
default_pass_schema = SHA512-CRYPT
password_query = SELECT email as user, password FROM virtual_users WHERE email='%u';
" > /etc/dovecot/dovecot-sql.conf.ext
chown -R $user1:dovecot /etc/dovecot
chown -R $user1:dovecot /var/run/dovecot/auth-userdb

service dovecot restart


# Enable ports
ufw allow 25
ufw allow 587
ufw allow 993

# Setting Up Spam Assassin
(sleep 2
echo $user1) | adduser spamd --disabled-login


update-rc.d spamassassin enable

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

echo "
Syslog                  yes
UMask                   002

AutoRestart             yes
AutoRestartRate         10/1h
Syslog                  yes
SyslogSuccess           yes
LogWhy                  yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
Socket                  inet:8892@localhost

PidFile               /var/run/opendkim/opendkim.pid
SignatureAlgorithm    rsa-SHA256
UserID                opendkim:opendkim
OversignHeaders       From
" > /etc/opendkim.conf

echo "Socket                  inet:8892@localhost" >> /etc/default/opendkim

echo "
127.0.0.1
localhost
192.168.0.1/24
::1

*.$my_domain
" > /etc/opendkim/TrustedHosts

echo "mail._domainkey.$my_domain $my_domain:mail:/etc/opendkim/keys/$user1/mail.private" > /etc/opendkim/KeyTable

mkdir /etc/opendkim/keys/$user1
cd /etc/opendkim/keys/$user1
opendkim-genkey -s usermail -d $my_domains 
chown opendkim:opendkim mail.private

service opendkim restart
service opendkim reload


# Restarting everything
newaliases
postfix start
service dovecot restart

echo "Congrats the script is finised. Check out /var/log/mail.log for any logs or errors"





