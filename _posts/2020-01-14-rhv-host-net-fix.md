---
layout: post
title:  "Create RHV Host Network via CLI"
date:   2020-01-14 16:00:00 +0500
categories: [ovirt, homelab]
---

Today I got myself into an interesting situation with my RHV cluster. As it
turned out all of the ovirtmgmt networks were removed from each host. This,
naturally, caused the cluster to crash and the hyperconverged Gluster storage
to stop. Not a happy place. This is also when I learned that one does not
simply add network interfaces to oVirt hypervisors.

What I learned is that the vdsm daemon has total control over the host's
networks. VDSM runs on each host and each host has a service called
`vdsm-network` that will generate the network-scripts from VDSM's database.
When a network change is requested via the VDSM API, it writes the update to
`/var/lib/vdsm/staging/netconf`. The change is then applied to the host. The
API caller would then run a health check to verify the change was successful.
If the change did not cause issues, the caller will make another API call to
VDSM to indicate the change was ssuccessful. VDSM then commits the new
configuration to `/var/lib/vdsm/persistent/netconf`.

So, let's say we need to re-add the ovirtmgmt network to the host. We need to
do it through the VDSM API. The easiest way to do this is with the
`vdsm-client` command on the host itself.

```bash
echo '{"bondings": {}, "networks": {"ovirtmgmt": {"nic": "eno1", "netmask": "255.255.255.0", "ipaddr": "192.168.4.19", "gateway": "192.168.4.1", "defaultRoute": true}}, "options": {"connectivityCheck": false}}' | vdsm-client -f - Host setupNetworks

# verify the change was successful

vdsm-client Host setSafeNetworkConfig
```

It might also be wise to give the system a reboot after this. Just to toggle
all the services and ensure the networks start properly on boot.

Sources
-------
  1. [Gist: phoracek/setup_ovirtmgmt.sh](https://gist.github.com/phoracek/0022434b1f105fa0466ed04576b6d7f4)
