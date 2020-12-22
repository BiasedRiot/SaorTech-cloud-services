#!/bin/bash

#Just a simple script for removing all the stuff so the mail_server script can be re-run

TEMP=`getopt -o d:u: --long domain: -- "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -d|--domain)
            my_domain=$2 ; shift 2;;
        -u|--user)
            user=$2 ; shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

apt-get --purge autoremove postfix postfix-mysql dovecot-core dovecot-imapd dovecot-lmtpd dovecot-pop3d dovecot-mysql spamassassin spamc opendkim opendkim-tools -y
rm -r /var/lib/dovecot/
rm -r /etc/dovecot/
rm -r /home/$user/Maildir/
echo "Removing DB"
(sleep 2
echo "DROP usermail;"
sleep 2) | mariadb

#certbot delete --cert-name $my_domain


