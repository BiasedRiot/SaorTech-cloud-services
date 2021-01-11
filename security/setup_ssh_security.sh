#!/bin/bash

# This script sets up Fail2Ban to prevent brute-force attacking attempts on your server. It also -
# prevents root login and PasswordAuthentication as this is ofter the target user of attackers and -
# it is a security best practice to remove this anyway.

# The email address is for notificaitions. You need to include it.

TEMP=`getopt -o e: --long email: -- "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -e|--email)
            my_email=$2 ; shift 2;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

# Simple flag check
if [ -z "$my_email" ] 
then
  echo "Email flag needs to be included"
  exit 1
fi

# Installing Fail2Ban
echo "Setting up fail2ban"
apt install fail2ban -y

# Writing my prefered configuration to jail.conf. I think 3 reties is enough before -
# someone gets sent to the gulag. The ban time is also a day instead of 10 minutes like default.
cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

echo "
[DEFAULT]
ignorecommand =
bantime = 1d
findtime = 10m
maxretry = 3
backend = auto
usedns = warn
logencoding = auto
enabled = false
mode = normal
filter = %(name)s[mode=%(mode)s]
destemail = $my_email
sender = root@
mta = sendmail
protocol = tcp
chain =
port = 0:65535
fail2ban_agent = Fail2Ban/%(fail2ban_version)s
banaction = iptables-multiport
banaction_allports = iptables-allports
action_abuseipdb = abuseipdb
action = %(action_)s
" > /etc/fail2ban/jail.conf

# Enabling the service
systemctl start fail2ban
systemctl enable fail2ban


# Un-authorizing root login
sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config


echo "Congradulations your SSH has had basic protection setup. "


