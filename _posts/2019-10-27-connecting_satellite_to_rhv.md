---
layout: post
title:  "Connecting Red Hat Satellite to Red Hat Virtualization"
date:   2019-10-27 16:00:00 +0500
categories: [homelab, ovirt, foreman]
---

Satellite integrates pretty well with Red Hat Virtualization (RHV) for the purposes of managing the lifecycle of your virtual machines. Primarily, this allows you to create a new machine in Satellite and have it automatically deployed on your RHV cluster. [Since we have already connected Satellite to IdM](https://rmkra.us/homelab/freeipa/foreman/2019/10/25/connecting_satellite_to_freeipa.html) for Realm and DNS management, this is the next step in having a single tool to manage our environment.

This article will cover Satellite integration with RHV, however similar steps are taken to integrate with VMware, AWS, or even Google Cloud.

Satellite Compute Resource
--------------------------

First, you'll want to add your RHV cluster to your Satellite server as a Compute Resource. This allows you to use the `Deploy On` option while creating a new machine.

1. Navigate to `Infrastructure` -> `Compute Resources`
2. Click `Create new resource`
3. On the `Compute Resources` tab:
| Field | Value |
|-------|--------|
| Name | Something usefule to you |
| Provider | RHV |
| URL | https://rhv.lab.rmkra.us/ovirt-engine/api |
| Use APIv4 | I recommend yes |
| Username | USER@AUTH_METHOD |
| Password | PASSWORD |
| Datacenter | Select one after clicking `Test Connection` |
| Quota ID | Default |
4. Fill out the `Locations` and `Organizations` tabs as you see fit
5. Click `Submit`
6. Select your new compute resource from the list
7. On the `Virtual Machines` tab, ensure you see an accurate list of machines in the cluster. For any machine that may already be managed by Satellite, click the name and then click `Associate VM` to have it be paired.
8. Fill out the `Compute Resources` tab as it makes sense to you. This will help when provisioning new machines.

That's about it. Now trying going to `Hosts` -> `All Hosts` and create a new machine. Ensure that you tell it to deploy on your RHV cluster. The VM will automatically be created and will start imaging as soon as it boots.

virt-who
--------

If you are using a Red Hat subscription that requires `virt-who`, like the Virtual Data Center (VDC) subscription, you'll need to configure this. `virt-who` is a tool that will connect to your virtualization environment and poll the hypervisors for their current virtual machines. This data is then used by Satellite to give VMs entitlements they inherit from their host.

There is a wizard for creating this configuration. It is in `Infrastructure` -> `Virt-who configurations`. Create a new configuration of type `Red Hat Virtualization Hypervisor (rhevm)`. The hypervisor server must be a full url, like `https://rhv.lab.rmkra.us:443/ovirt-engine/`. The user name also must be fully qualified, like `USER@AUTH_METHOD`. The default settings should be good for the rest.

Once the configuration is created, you can export it and find a `Deploy` tab. In that tab are two deployment methods, one uses hammer and the other is a custom script. SSH into your Satellite server and run either of these methods. I used the script.

After `virt-who` starts, you should see new entries in `Content hosts` that relate to your hypervisors. Attach your subscription to this new entry. If you are not seeing these new entries, first try enabling `virt-who` debugging in `/etc/sysconfig/virt-who`. If no error messages appear in the log, make sure your hypervisors are not managed hosts as that can cause conflicts. More information can be found in Source 2.

RHV Foreman Provider
--------------------

You could set this up if you'd like. This integration is less useful. It allows new Hosts to be added in RHV more easily. This can be done from the RHV interface in `Administration` -> `Providers`. Create a new `Foreman/Ansible` provider.

That's it
---------

Now that RHV and Satellite are connected, you can manage the full lifecycle of virtual machines from the Satellite interface. You can even control the power state of the virtual machines the way you might control a server with IPMI.

Sources
-------
  1. [Provisioning Virtual Machines in Red Hat Virtualization](https://access.redhat.com/documentation/en-us/red_hat_satellite/6.6/html/provisioning_guide/provisioning_virtual_machines_in_red_hat_virtualization)
  2. [Servers not showing up as content-hosts with virt-who](https://access.redhat.com/solutions/3998041)
  3. [Introduction to External Providers in Red Hat Virtualization](https://access.redhat.com/documentation/en-us/red_hat_virtualization/4.2/html-single/administration_guide/index#Introduction_to_Third_Party_Resource_Providers_in_Red_Hat_Enterprise_Virtualization)
