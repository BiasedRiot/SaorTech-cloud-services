
# Installing Postfix
echo "Setting up postfix"
wget -O- https://repo.dovecot.org/DOVECOT-REPO-GPG | sudo apt-key add -
echo "deb https://repo.dovecot.org/ce-2.3-latest/ubuntu/$(lsb_release -cs) $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/dovecot.list

apt update
debconf-set-selections <<< "postfix postfix/mailname string $(hostname -f)"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt install postfix postfix-mysql dovecot-imapd dovecot-lmtpd dovecot-pop3d dovecot-mysql

#Configuring Postfix
mkdir -p /etc/postfix/sql
( sleep 2
echo "user = postfixadmin"
sleep 2
echo "password = P4ssvv0rD"
sleep 2
echo "hosts = 127.0.0.1"
sleep 2
echo "dbname = postfixadmin"
sleep 2
echo "query = SELECT domain FROM domain WHERE domain='%s' AND active = '1'") | cat > /etc/postfix/sql/mysql_virtual_domains_maps.cf

( sleep 2
echo "user = postfixadmin"
sleep 2
echo "password = P4ssvv0rD"
sleep 2
echo "dbname = postfixadmin"
sleep 2
echo "query = SELECT goto FROM alias WHERE address='%s' AND active = '1'") | cat > /etc/postfix/sql/mysql_virtual_alias_maps.cf

( sleep 2
echo "user = postfixadmin"
sleep 2
echo "password = P4ssvv0rD"
sleep 2
echo "dbname = postfixadmin"
sleep 2
echo "query = SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain = '%d' and alias.address = CONCAT('%u', '@', alias_domain.target_domain) AND alias.active = 1 AND alias_domain.active='1'") | cat > /etc/postfix/sql/mysql_virtual_alias_domain_maps.cf

( sleep 2
echo "user = postfixadmin"
sleep 2
echo "password = P4ssvv0rD"
sleep 2
echo "dbname = postfixadmin"
sleep 2
echo "query = SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain = '%d' and alias.address = CONCAT('@', alias_domain.target_domain) AND alias.active = 1 AND alias_domain.active='1'") | cat > /etc/postfix/sql/mysql_virtual_alias_domain_catchall_maps.cf

( sleep 2
echo "user = postfixadmin"
sleep 2
echo "password = P4ssvv0rD"
sleep 2
echo "dbname = postfixadmin"
sleep 2
echo "query = SELECT maildir FROM mailbox WHERE username='%s' AND active = '1'") | cat > /etc/postfix/sql/mysql_virtual_mailbox_maps.cf

( sleep 2
echo "user = postfixadmin"
sleep 2
echo "password = P4ssvv0rD"
sleep 2
echo "dbname = postfixadmin"
sleep 2
echo "query = SELECT maildir FROM mailbox,alias_domain WHERE alias_domain.alias_domain = '%d' and mailbox.username = CONCAT('%u', '@', alias_domain.target_domain) AND mailbox.active = 1 AND alias_domain.active='1'") | cat > /etc/postfix/sql/mysql_virtual_alias_domain_mailbox_maps.cf


# Update PostFix configuration
postconf -e "virtual_mailbox_domains = mysql:/etc/postfix/sql/mysql_virtual_domains_maps.cf"
postconf -e "virtual_alias_maps = mysql:/etc/postfix/sql/mysql_virtual_alias_maps.cf, mysql:/etc/postfix/sql/mysql_virtual_alias_domain_maps.cf, mysql:/etc/postfix/sql/mysql_virtual_alias_domain_catchall_maps.cf"
postconf -e "virtual_mailbox_maps = mysql:/etc/postfix/sql/mysql_virtual_mailbox_maps.cf, mysql:/etc/postfix/sql/mysql_virtual_alias_domain_mailbox_maps.cf"

# Set Dovecot LMTP service as default
postconf -e "virtual_transport = lmtp:unix:private/dovecot-lmtp"

# TL Parameters
postconf -e 'smtp_tls_security_level = may'
postconf -e 'smtpd_tls_security_level = may'
postconf -e 'smtp_tls_note_starttls_offer = yes'
postconf -e 'smtpd_tls_loglevel = 1'
postconf -e 'smtpd_tls_received_header = yes'
postconf -e 'smtpd_tls_cert_file = /etc/letsencrypt/live/mail.linuxize.com/fullchain.pem'
postconf -e 'smtpd_tls_key_file = /etc/letsencrypt/live/mail.linuxize.com/privkey.pem'

#Configure SMTP
postconf -e 'smtpd_sasl_type = dovecot'
postconf -e 'smtpd_sasl_path = private/auth'
postconf -e 'smtpd_sasl_local_domain ='
postconf -e 'smtpd_sasl_security_options = noanonymous'
postconf -e 'broken_sasl_auth_clients = yes'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination'


#Enable port 587 and 465

