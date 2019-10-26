---
layout: post
title:  "Connecting Red Hat Satellite to Red Hat IdM"
date:   2019-10-25 16:00:00 +0500
categories: [homelab, freeipa, foreman]
---

Red Hat Satellite (built from the upstream, Foreman) is a great solution for managing your Red Hat infrastructure. It handles patch management, subscription management, system lifecycle management, and is ultimately a great source of truth for your Red Hat servers.

Red Hat IdM (upstream FreeIPA), is a great product managing your Linux domain. It is focused on user authorization and authentication and zone management.

Together, these products compliment each other well.

This article will discuss deploying a single Red Hat Satellite 6.6 server with integration to Red Hat IdM. We will have Satellite use the IdM server for authentication and send DNS updates to IdM rather than managing its own zone.

Prepare Satellite Server
------------------------
Chapter 1 of the [installation manual](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.6/html/installing_satellite_server_from_a_connected_network/index) covers general system prep.

1. Ensure there is 500 GB available at `/var/lib/pulp`.
2. Attach the system to your Red Hat account and assign it a Satellite entitlement.
3. Attach the proper repositories. **NOTE:** Do not attach the EPEL, it will break the install process.

  ```bash
  subscription-manager repos --enable=rhel-7-server-rpms \
  --enable=rhel-server-rhscl-7-rpms \
  --enable=rhel-7-server-satellite-6.6-rpms \
  --enable=rhel-7-server-satellite-maintenance-6-rpms \
  --enable=rhel-7-server-ansible-2.8-rpms
  ```

4. Join the Satellite server to your IPA Domain. Do this by your standard procedure using `ipa-client-install`.
5. Create a service account in the Kerberos realm for the Satellite server.

  ```bash
  ipa service-add capsule/sputnik.lab.rmkra.us
  ```

6. Create a Keytab file for this account.

  ```bash
  ipa-getkeytab -p capsule/sputnik.lab.rmkra.us@LAB.RMKRA.US \
  -s ipa.lab.rmkra.us -k /etc/foreman-proxy/dns.keytab

  chown foreman-proxy:foreman-proxy /etc/foreman-proxy/dns.keytab
  ```

7. Open firewall ports.

  ```bash
  firewall-cmd \
  --add-port="53/udp" --add-port="53/tcp" \
  --add-port="67/udp" --add-port="69/udp" \
  --add-port="80/tcp"  --add-port="443/tcp" \
  --add-port="5000/tcp" --add-port="5647/tcp" \
  --add-port="8000/tcp" --add-port="8140/tcp" \
  --add-port="9090/tcp"

  firewall-cmd --runtime-to-permanent
  ```

Install Satellite
-----------------

Chapter 2 of the [installation manual](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.6/html/installing_satellite_server_from_a_connected_network/index) covers the basic install procedure for a connected install. Refer there for the full version, but here is the short version.

1. Download the installation packages.

  ```bash
  yum install satellite
  ```

2. Create an answer file to specify how Satellite should be installed.

  ```bash
  cp /etc/foreman-installer/scenarios.d/satellite-answers.yaml \
  /etc/foreman-installer/scenarios.d/my-answer-file.yaml
  ```

3. Edit the answer file to cover your desired install options. A couple of important ones are noted here, but look at them all.

  ```yaml
  # ...
  foreman_proxy:
      # ...
      # Enable tftp for PXE booting
      tftp: true  
      # ...
      # I don't use Satellite for DHCP in my environment, you can, though
      dhcp: false
      # ...
      # Tell Satellite to send DNS updates to IdM
      dns: true
      dns_provider: nsupdate_gss
      dns_interface: primary
      dns_zone: lab.rmkra.us
      dns_reverse: 4.168.192.in-addr.arpa
      dns_server: ipa.lab.rmkra.us
      dns_ttl: 86400
      dns_tsig_keytab: /etc/foreman-proxy/dns.keytab
      dns_tsig_principal: capsule/sputnik.lab.rmkra.us@LAB.RMKRA.US
      dns_forwarders: []
      # ...
      # I have some IPMI servers, so I enable this
      bmc: true
      bmc_default_provider: ipmitool
  foreman_proxy::plugin::discovery:
      install_images: true
  # ...
  ```

4. Tell the installer to use your custom answers file by editing `/etc/foreman-installer/scenarios.d/satellite.yml` and editing the answers file line.

  ```yaml
  :answer_file: /etc/foreman-installer/scenarios.d/my-answer-file.yaml
  ```

5. Install Satellite

  ```bash
  satellite-installer --scenario satellite
  ```

6. Change the admin password. I don't like hardcoding it into the answers file.

  ```bash
  foreman-rake permissions:reset
  ```

Enable Bare Metal Discovery
---------------------------

1. Install discovery PXE images.

  ```bash
  foreman-maintain package install foreman-discovery-image
  ```

2. Set Discovery options in `Administer` -> `Settings` -> `Discovered` tab
  - Discovery location
  - Discovery organization

3. Set auto discover to be the default behavior for unknown hosts in `Administer` -> `Settings` -> `Provisioning` tab
  - Default PXE global template entry: discovery

4. Build default PXE template.
  1. In the UI, go to `Hosts` -> `Provisioning Templates`
  2. Click `Build PXE Default`

Configure Satellite
-------------------

Login to the GUI and do all the basic configuration. Load a manifest, sync repos, create content views, etc. When creating your domain, ensure the DNS capsule is set to the capsule server you've configured to send updates to IdM. When creating your subnet, set `IPAM` to `None`, and ensure the `Reverse DNS Capsule` is set to the capsule server you've configured to talk to IdM.

The following are the settings required for configuring authentication back to IdM and making an IdM group called `admin` map to a Satellite group called `Admins` that grants administrative access to Satellite.

1. In the Satellite GUI, go to `Administer` -> `LDAP Authentication`
2. Click `Create LDAP Source`
  1. Answers for the `LDAP server` tab:
    - Name: Whatever you'd like
    - Server: ipa.lab.rmkra.us
    - LDAPS: Checked
    - Port: 636
    - Server type: FreeIPA
  2. `Account` tab:
    - Account Username: uid=SERVICE,cn=users,cn=accounts,dc=lab,dc=rmkra,dc=us
    - Account Password: The associated password
    - Base DN: cn=users,cn=accounts,dc=lab,dc=rmkra,dc=us
    - Groups base DN: cn=groups,cn=accounts,dc=lab,dc=rmkra,dc=us
    - Automatically Create Accounts in Satellite: Checked
    - Usergroup Sync: Checked
  3. `Attribute mappings` tab:
    - Login Name Attribute: uid
    - First Name Attribute: givenName
    - Surname Attribute: sn
    - Email Address Attribute: mail
  4. Click `Submit`
3. In the Satellite GUI, go to `Administer` -> `User Groups`
4. Click `Create User Group`
  1. `User Group` tab:
    - Name: Admins
  2. `Roles` tab:
    - Administrator: Checked
  3. `External Groups` tab:
    - Click `+ Add external user group`
    - Name: admins
    - Auth Source: LDAP-ipa.lab.rmkra.us
  4. Click `Submit`
5. Log out and log back in with your standard account.

Configure IdM
-------------

Your DNS zones in IdM must be configured to allow updates from Satellite's service account. Append the following line to the `BIND update policy` box for the forward and reverse domains:

  ```
  grant capsule\047sputnik.lab.rmkra.us@LAB.RMKRA.US wildcard * ANY;
  ```

On both zones, ensure that `Dynamic update` is set to `True`. Ensure that `Allow PTR sync` is enabled for the forward lookup zone.

Bask in the automated glory that is your life
---------------------------------------------

When new machines are created, DNS entries will appear automatically. Forward and reverse. For custom additional entries (VIPs and the like), you can still manage them in IdM directly. Success.

Sources
-------
  - [Satellite Installation Manual](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.6/html/installing_satellite_server_from_a_connected_network/index)
  - [Configuring Satellite or Capsule with External IdM DNS](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.6/html/installing_satellite_server_from_a_connected_network/configuring_external_services#configuring_satellite_external_idm_dns)
  - [Configuring the Satellite Discovery Plugin](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.6/html/managing_hosts/chap-red_hat_satellite-managing_hosts-discovering_bare_metal_hosts_on_satellite#sect-Red_Hat_Satellite-Managing_Hosts-Discovering_Bare_metal_Hosts_on_Satellite-Configuring_the_Satellite_Discovery_Plug_in)
