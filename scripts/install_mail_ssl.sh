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


# Installing Postfix
echo "Installing requirements"
apt update -y
debconf-set-selections <<< "postfix postfix/mailname string $my_domain"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

apt install apache2 postfix postfix-mysql dovecot-core dovecot-imapd dovecot-lmtpd dovecot-pop3d dovecot-mysql spamassassin spamc -y

echo "Setting up encryption"
#apt install certbot -y 
#service apache2 stop
#certbot certonly --standalone -d $my_domain --redirect
#service apache2 restart

postfix stop

#Configure TLS
postconf -e "smtpd_tls_cert_file=/etc/letsencrypt/live/$my_domain/fullchain.pem"
postconf -e "smtpd_tls_key_file=/etc/letsencrypt/live/$my_domain/privkey.pem"
postconf -e 'smtpd_use_tls=yes'
postconf -e 'smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache'
postconf -e 'smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache'

#Configure SMTP
postconf -e 'smtpd_sasl_type = dovecot'
postconf -e 'smtpd_sasl_path = private/auth'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtp_tls_security_level = may'
postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject'
postconf -e "mydestination = $FQDN, $my_domain, localhost, localhost.localdomain"
postconf -e "myorigin = $my_domain"
postconf -e "myhostname = $FQDN"

#Configure Virtual Domains
postconf -e 'alias_database = hash:/etc/aliases'
postconf -e 'alias_maps = hash:/etc/aliases'

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


#Adding aliases to file
echo "Setting up aliases"
echo "
mailer-daemon: postmaster
postmaster: root
webmaster: root
root: $user1
$alias1: $user1
$alias2: $user1
$alias3: $user1
" > /etc/aliases


#Dovecot stuff
echo "
disable_plaintext_auth = no
mail_privileged_group = mail
mail_location = mbox:~/mail:INBOX=/var/mail/%u
userdb {
  driver = passwd
}
passdb {
  args = %s
  driver = pam
}
protocols = " imap"

protocol imap {
  mail_plugins = " autocreate"
}
plugin {
  autocreate = Trash
  autocreate2 = Sent
  autosubscribe = Trash
  autosubscribe2 = Sent
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    group = postfix
    mode = 0660
    user = postfix
  }
}

ssl_cert = </etc/letsencrypt/live/$my_domain/fullchain.pem
ssl_key = </etc/letsencrypt/live/$my_domain/privkey.pem
" > /etc/dovecot/dovecot.conf

#Enabling ports
ufw allow 25
ufw allow 587
ufw allow 465
ufw allow 993

#Setting up Spamassassin
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


newaliases
postfix start
service dovecot restart
