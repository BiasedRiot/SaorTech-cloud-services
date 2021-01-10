# SaorTech-cloud-services
The purpose of this project is to make setting up and configuring open-source alternatives to google, Dropbox etc... as simple as possible. This repository contains scripts for various open-source services and more are being added whenever I feel like I need them in my life I don't like relying of services like dropbox of gmail so whenever I find a good and free alternative I'll create an automation script and add it to this repo. Run any of the scripts on a VPS or an instance to set it up. So far only tested for Ubuntu v20.

Check out my video explaining the services further: https://www.youtube.com/watch?v=xebRvQdF4uo

## Setup guide
Before you do anything you need to make sure that you have a domain and that relevant A class/ MX subdomains are set up. There are pleanty of cheap domain services availible and in the case of .tk you can sometimes get free ones.

Run git clone to get the scripts on your server

```
git clone https://github.com/CoogyEoin/SaorTech-cloud-services.git

```

Figure out which services you want (Discussed below) and add the neccessary values with CLI arguments (email, domain, user etc...). I currently run the *install_mail_server_with_sll.sh* script as the other mail script has some issues and I prefer just signing in with a user on a minimal client.

Then just run the script.

```
./SaorTech-cloud-services/<Whichever service you want> <Whichever flags needed>
```


## Current services availible
* Nextcloud (Storage/Calendar)
* Mail server (Postfix and Dovecot)
* Static Website/portfolio (Apache)
* Git Server
* Fail2Ban /SSH protection

## Services I considered being added
* Bit Warden
* Media Centre
* SimpleLogin
* Ansible
* VPN (cringe)

## Additional Features To Add

* Migrate to Ansible to support more platforms/ Operating Systems
* Add script for running specific scripts eg: only mail and nextcloud
