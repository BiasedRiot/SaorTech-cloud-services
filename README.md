# SaorTech-cloud-services
The purpose of this project is to make setting up and configuring open-source alternatives to google, Dropbox etc... as simple as possible. I don't like relying of services like dropbox of gmail so whenever I find a good and free alternative I'll create an automation script and add it to this repo. This repository contains scripts for various open-source services and more are being added whenever I feel like I need them in my life. Run any of the scripts on a VPS or an instance to set it up. So far only tested for Ubuntu v20.


## Setup guide
Before you do anything you need to make sure that you have a domain and that relevant A class/ MX subdomains are set up. There are pleanty of cheap domain services availible and in the case of .tk you can sometimes get free ones.

Run git clone to get the scripts on your server

```
git clone https://github.com/CoogyEoin/SaorTech-cloud-services.git

```

Figure out which services you want (Discussed below) and edit the values such as email, domain, user etc... in the scripts.

Then just run the script.

```
./SaorTech-cloud-services/<Whichever service you want>
```


## Current services availible
* Nextcloud (Storage/Calendar)
* Mail server (Postfix and Dovecot)

## Services being added
* Bit Warden
* Provision space in apache for personal website eg: portfolio
* Media Centre
* SimpleLogin
* Git/ Ansible
* VPN (cringe)

## Additional Features To Add

* Additional Configuation of Nextcloud (Calander etc...)
* Get mailserver fully operational (OpenDKIR, ports etc)
* Interactive mode to pick and choose specific services + insert details like domains
* Microservice architecture 
* Add support for additional Operating Systems and versions 
