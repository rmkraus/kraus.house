---
layout: post
title:  "Building a Simple Hadoop Cluster"
date:   2018-10-08 23:00:00 +0500
categories: [hadoop, bigdata, ansible]
---

Hadoop has become the defacto file system for I/O intensive big data
applications. Hadoop differentiates itself from traditional distributed
filesystems with its principle of data locality. Built into the filesystem is a
job scheduler (by default, Yarn) that is able to execute jobs of a specific
type (by default, MapReduce) directly on the storage cluster. It is even
possible to define the topology of the cluster so that Yarn can execute work on
nodes closest to the data on which they will operate. This allows these data
processing jobs to operate at near native-device speeds.

Truth be told, however, Hadoop is actually a slow(er) filesystem... at least
when compared to others like Lustre, GPFS, WekaIO, etc. If your workload does
not easily fit MapReduce, or one of the other Hadoop compatible analytics
engines, then maybe Hadoop is not for you. The following are the reasons to
consider Hadoop:

* Data Locality when using HDFS Analytics Engines
* Lower Cost - Data drives do not require RAID in production
* Highly scalable
* Efficiently manages large amounts of unstrctured data

## Simple Cluster Setup

We can get started with Hadoop by building a simple cluster.

![Simple Hadoop](https://raw.githubusercontent.com/rmkraus/kraus.house/master/static/img/_posts/hdfs-simple.png  "Simple Hadoop Architecture")

This cluster will consist of three nodes and one client. Each node will have a
single storage device which means one drive for metadata and two drives for
data. The following steps will be followed to create the cluster.

1. Create local hadoop system account for running the daemons.
2. Distribute hadoop user SSH key from the master to the worker nodes.
3. Install/configure Java and dependencies.
4. Download, extract, and install the compiled release of Hadoop.
5. Format Hadoop drives as ext3.
6. Configure Hadoop:
  * Set the correct Java runtime.
  * core-site.xml - Defines master node
  * hdfs-site.xml - Defines data directories and data replication.
  * mapred-site.xml - Defines the MapReduce options and scheduler type.
  * yarn-site.xml - Defines YARN configuration and resource manager.
  * workers - List of all cluster worker nodes.
7. Configure host firewalls.

## Deployment with Ansible

Anything that is worth doing is worth being automated. I have automated this
deployment with Ansible. The role, playbook, and example inventory file can
be [downloaded from GitHub](https://github.com/rmkraus/ansible-hadoop).

To use this playbook, customize the values in the inventory file at
`hosts/hadoop`. The current values match the diagram above. Be sure that all of
the nodes in the Hadoop cluster can reach the internet. If they cannot, be sure
to configure the proxy settings. Lastly, be sure to verify the settings in
`ansible.cfg`. By default, Ansible will assume it can SSH to the node as the
current user without a password and then sudo to root without a password.

Once everything has been configured to your site-specific settings, you can
launch the playbook. From the repository root directory:

```bash
ansible-playbook -l hadoop playbooks/hadoop.yml
```

Once this has finished running, you should *almost* have a functional hadoop
cluster. The Hadoop software has been installed to `/opt/hadoop/hadoop-3.1.1`.
The binaries and configuration files are all in this directory structure. All
that is left to do is format your HDFS file system and start the daemons.

To format the filesystem, from the master node, issue the following command:

```bash
hdfs namenode -format
```

To start the Hadoop daemons, become the hadoop user and issue the start
commands.

```bash
sudo su - hadoop
/opt/hadoop/hadoop-3.1.1/sbin/start-dfs.sh
/opt/hadoop/hadoop-3.1.1/sbin/start-yarn.sh
```

To shutdown the HDFS filesystem, use the stop commands.

```bash
sudo su - hadoop
/opt/hadoop/hadoop-3.1.1/sbin/stop-dfs.sh
/opt/hadoop/hadoop-3.1.1/sbin/stop-yarn.sh
```

## Next Steps

In future posts, we'll explore:
* Interacting with the Filesystem and Running MapReduce Jobs
* Installing Spark and Querying Data
* Considerations for Production Deployments
