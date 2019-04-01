---
layout: post
title:  "Securing UniFi Cloud Key with Let's Encrypt Certificates"
date:   2019-03-31 23:00:00 +0500
categories: [security, networking, unifi, ssl, ansible]
---

Ubiquity's UniFi networking gear is a great setup to drive your home lab. You
get nearly all of the advanced features you need in a prebuilt package.
Unfortunately, since everything is prebuilt, you need to work pretty hard to
accomplish some tasks that would otherwise be pretty basic. Still, though,
first world problem.

Today, we are going to be updating the SSL certificates used by the UniFi
Cloud Key. Honestly, this should probably be easier to accomplish than it is.
However, what is the risk of running self-signed certificates inside of your
home network? Probably pretty minimal. However, publicly signed are better and
publicly signed and trusted certificates will come in really handy as we start
to automate against the UniFi API.

Since this is Home Lab, we are being cheap and will be using Let's Encrypt for
the certificates. This makes the process a bit more challenging, but not
impossible. Let's get started.

## Prerequisites

In order for this to work, you must own a domain name and use that as the base
domain for your network. It serves to reason that you must also have proper DNS
resolution inside of your network. As long as you own the base domain, you
COULD get away with using /etc/hosts entries, but obviously that is not ideal.

If you cannot meet this prerequisite, then you will not be able to get a
trusted SSL certificate from Let's Encrypt or any paid Certificate Authority.

## Process Overview

Something that is important to note before getting started is that on the
Cloud Key, there are actually two processes hosting HTTPS traffic on the
network. First, there is NGINX. This hosts traffic on ports 80/443, although 80
simply redirects to 443. This hosts the web console for managing the Cloud Key.
There is then another process, unifi. This is the web console used to manage
your Ubiquity network and it is a Java program listening on port 8443. Since we
are in town, we'll update the certs for both of these applications.

Let's quickly go over the whole process before going in-depth in each step.

  1. Generate a private key and public SSL certificates.
  2. Create a PKCS12 keystore file from the certs and keys.
  3. Prepare the Cloud Key for a peristent and custom key store.
  4. Upload all certificates, keys, and the keystore onto the Cloud Key.
  5. Change the NGINX configuration to use the newly uploaded keys.
  6. Import the PKCS12 Keystore into the JKS Keystore used by UniFi.
  7. Restart HTTPS hosting services.
  8. Clean up.

## Generate a private key and public SSL certificates

We're going to use Certbot as our Let's Encrypt client as it is, arguably, the
most popular. We're going to run Let's Encrypt from another machine rather than
our Cloud Key directly because installing and running third party software on
the Cloud Key is inadvisable. Because we are running Certbot on a machine
seperate from the one we are certifying, and because the URL for your Cloud Key
is probably only accessible inside of your network, we'll have to use ACME DNS
verification.

The following certbot command will kick off this process:

```bash
certbot certonly \
    --manual-public-ip-logging-ok --text \
    --agree-tos --expand --renew-by-default \
    --manual --preferred-challenges=dns \
    --email you@email.com \
    -d ubnt.my.network.com
```

Certbot will then come back requesting that you create a TXT record at a domain
like the following:

```
_acme_challenge.ubnt.my.network.com
```

Once you create the entry, wait for Google's DNS servers to pick up the change
before continuing. You can monitor the status of the entry with the following
command.

```bash
dig @8.8.8.8 _acme_challenge.ubnt.my.network.com TXT
```

Once that commnand returns your new entry, tell Certbot to continue, it will
verify your ownership of the domain by checking for the DNS entry, and then
generate your public key. By default, Certbot will store certificates and keys
in the following directory.

```
/etc/letsencrypt/config/live/ubnt.my.network.com
```

In this directory, you'll find the following files:

  * cert.pem - Your publicly signed certificate
  * chain.pem - The Certificate Authority's public certificate
  * fullchain.pem - Your public certificate with the CA's certificate
  * privkey.pem - Your private key (NEVER SHARE THIS)

## Create a PKCS12 keystore file from the certs and keys

The UniFi application uses key store archives for managing SSL certs
and keys. This is different from the approach most commonly used with Apache or
NGINX where you point to each type of certificate and key individually in the
configuration file. A key store file is simply a binary file that contains the
private key, the public certificate, and the CA's chain of certs in one neat,
password protected bundle. UniFi uses JKS formated keystores, but we'll start
by generating a PKCS12 formatted bundle first.

```bash
openssl pkcs12 -export \
    -inkey /etc/letsencrypt/config/live/ubnt.mynetwork.com/privkey.pem \
    -in /etc/letsencrypt/config/live/ubnt.mynetwork.com/fullchain.pem \
    -out cert.p12 -name unifi -password pass:temppass
```

This will output your PKCS12 formatted archive protected by the pasword
"temppass".

## Prepare the Cloud Key for a peristent and custom key store

The Cloud Key is not made to be tinkered with. So, in order to tinker, we have
to do some extra tinkering. These changes will make it so that our custom keys
are not overwritten every time the Cloud Key reboots. To perform these changes,
SSH into the Cloud Key using the username "ubnt" and your admin password.

  1. First, we want to edit the file /etc/defaults/unifi and comment out the
     line that defines UNIFI_SSL_KEYSTORE by placing a # at the begining of the
     line. This variable is used for the Cloud Key to link to the correct
     keystore. Without this variable, UniFi does not attempt to fix the
     keystore.
  2. We need to unlink the keystore used by UniFi. The UniFi application reads
     the keystore from /usr/lib/unifi/data/keystore. By default, this will be a
     link to /etc/ssl/private/unifi.keystore.jks. That link will not be
     recreated because the changes from step 1, but that JKS file will be
     reverted each time the Cloud Key boots. Run unlink on that file so we can
     make a fresh one.
  3. Create a directory that will be persistent across reboots. The location is
     not so important, but I use /root/ssl_certs. Make sure the folder is owned
     by root:root with a mode of 0700.

## Upload all certificates, keys, and the keystore onto the Cloud Key

Use SCP to upload all of the PEM files from Certbot as well as the PKCS12
archive to your Cloud Key in the folder we just created (/root/ssl_certs, for
example). All of these files should also be owned by root:root with a mode of
0600.

## Change the NGINX configuration to use the newly uploaded keys

The certificates that NGINX uses by default are overwritten on every reboot.
The NGINX configuration itself, however, is not. So we cannot replace the
default keys, but we can change the configuration files to point to our new
keys. The configuration file you care about is located at:

```
/etc/nginx/sites-enabled/cloudkey-webui
```

In this file, you are looking for two variables: ssl_certificate and
ssl_certificate_key. The certificate variable needs to point to your public
certificate, but it is even better to point to the full chain. This allows your
webserver to pass your public cert and the CA's certs during the handshake. The
certificate key variable should point to your private key. Continuing the
examples from above, the two lines should look like this:

```
        ssl_certificate /root/ssl_certs/fullchain.pem;
        ssl_certificate_key /root/ssl_certs/privkey.pem;
```

Once you have made your changes, you'll want NGINX to verify the configuration
looks correct. You can do that with the following command.

```bash
nginx -t
```

You'll want to fix any errors this reports.

## Import the PKCS12 Keystore into the JKS Keystore used by UniFi

Now we are going to take that PKCS12 keystore we created and import it into
UniFi's JKS keystore. The password for the keystore we created was temppass,
but the password used by UniFi's keystore is aircontrolenterprise. We perform
this action with the following command.

```bash
keytool -importkeystore -noprompt -alias unifi \
    -deststorepass aircontrolenterprise \
    -destkeypass aircontrolenterprise \
    -destkeystore /usr/lib/unifi/data/keystore \
    -srckeystore /root/ssl_certs/cert.p12 \
    -srcstoretype PKCS12 \
    -srcstorepass temppass
```

This command should report success. You can verify the operation by listing the
keys in UniFi's keystore with the following command.

```bash
keytool -list -alias unifi -storepass aircontrolenterprise -v \
    -keystore /usr/lib/unifi/data/keystore  | less
```

## Restart HTTPS hosting services

This one is simple.

```bash
service nginx restart
service unifi restart
```

The UniFi service takes about a minute to restart, so don't worry too much.
Once the services have restarted, point your web broser at the Cloud Key to
ensure the changes were successful. You should be able to pull up the Cloud Key
management page as well as the UniFi portal. If the UniFi portal does not come
up, verify the command used to import the keystore archive. If the passwords or
alias are not correct, the UniFi service will come up, but will be unable to
serve any HTTPS pages.

## Clean up

This is mostly optional, but you could remove some of the extra files we no
longer need.

```bash
rm /root/ssl_certs/cert.p12 \
    /root/ssl_certs/chain.pem \
    /root/ssl_certs/cert.pem
```

Now is also a good time to double check the permissions on your keys.

```bash
chown root:root /root/ssl_certs \
    /root/ssl_certs/privkey.pem \
    /usr/lib/unifi/data/keystore
chmod 0700 /root/ssl_certs
chmod 0600 /root/ssl_certs/privkey.pem \
    /usr/lib/unifi/data/keystore
```

And that's it!

## Ansible Saves the Day

Wow, what a doozy. Like I said, should be easier, right? Oh well, at least we
can learn from our mistakes. Chances are these changes will not persist
firmware updates. Also, our Let's Encrypt certs, while free, do expire every 90
days. So we know we'll be doing this again. And you know what is worse than
doing something once? Doing it twice. Let's automate.

Luckily for you, I've already done the work. In my Ansible repository, you can
find [an Ansible Playbook for performing most of the steps we've
discussed.](https://github.com/rmkraus/ansible/blob/master/playbooks/unifi_update_certs.yml)
This playbook will automate all the steps except generating your Let's Encrypt
certificates. You will need to put together an inventory file to tell Ansible
how to connect to your Cloud Key as well as where Let's Encrypt is storing your
certs. I have also posted [my inventory file as an
example.](https://github.com/rmkraus/ansible/blob/master/hosts.network.ini)

Once you have your inventory file setup and Let's Encrypt certs generated,
simply execute the playbook:

```bash
ansible-playbook unifi_update_certs.yml -i inventory.ini
```

The rest should be magic.

## Whats Next

Now that we have proper SSL certificates on our UniFi interface, we can start
playing with the [undocumented REST
API.](https://ubntwiki.com/products/software/unifi-controller/api) A sneak
preview of that can be found [in some of my Ansible
roles.](https://github.com/rmkraus/ansible/tree/master/roles/unifi)

We can also rest easy knowing that we made it a bit more difficult for a bad
actor to man-in-the-middle our Cloud Key after they have already gained access
to our network. You know, if that's the kind of thing that keeps you up at
night.

## External Sources

* "Using Lets Encrypt to secure cloud-hosted services like Ubiquiti's mFi, Unifi and Unifi Video." 13 Dec. 2015, [https://lg.io/2015/12/13/using-lets-encrypt-to-secure-cloud-hosted-services-like-ubiquitis-mfi-unifi-and-unifi-video.html](https://lg.io/2015/12/13/using-lets-encrypt-to-secure-cloud-hosted-services-like-ubiquitis-mfi-unifi-and-unifi-video.html).
