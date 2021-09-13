# ocp4-sno-scripts
## Description

**Disclaimer: This procedure is not officially supported, it has been written just for testing purposes.**

This repository contains a set of scripts to deploy SNO (Single Node OpenShift) on Baremetal.
This procedure deploys a set of virtual machines (the installer and the SNO node itself on a hypervisor.

## Requirements
Basically, the requirements to be successful in deploying SNO (Single Node OpenShift) on a hypervisor, are:
* Libvirt and qemu-kvm installed on that hypervisor.
* Pull secret from cloud.openshift.com, it will be included afterwards in the installation script.
* Libvirt uses dnsmasq to service virtual networks, if you have your own dnsmasq deployed, take this into consideration: https://wiki.libvirt.org/page/Libvirtd_and_dnsmasq

## Procedure details
1. 00_create_sno_infra.sh - Creates SNO infrastructure on the hypervisor. On this first stage the following assets will be created:
   - The SNO Virtual Machine.
   - Virtual Networks, the network name is hardcoded, but you can edit any of these scripts and change the network name. Network ranges can be changed as well editing the corresponding parameters.
   - Install the installer server, this is the VM we'll use to deploy the whole cluster, avoiding messing the hypervisor. This VM is installed with a CentOS image downloaded by this same process.
   - Qemu disk images for master and workers are created and virtual machines configured with specific MAC addresses.
   - DNS records and DHCP reservations are set up in dnsmasq.
   - This is the only script that needs to be executed on the hypervisor, the other scripts are automatically copied to the installer VM, so the next steps will run on that installer VM.
   - At execution time you can provide custom domain name and cluster name, in order to set up these values use `-d` and `-c` options.

2. 01_pre_reqs_sno.sh - Install the required packages and finish the set up to deploy OpenShift IPI correctly **on the installer VM**. The following tasks are done under the hood:
   - Install some required packages, like libvirt libs and client, ironicclient, some other python modules, httpd, podman, etc.
   - Install and configure the sushy service - Virtual Redfish, to emulate bare metal machines by means of virtual machines. That way the installer will be able to power on, power off and manipulate the VMs as if it were bare metal servers.
   - Create the install-config.yaml file, **It is required to paste your own pull secret, replace it with <INSERT_YOUR_PULL_SECRETS_HERE> line**
   - Downloads oc and OpenShift installer client based on the OpenShift release.
   - Downloads RHCOS the RHCOS image to boot and do the initial installation of the SNO.
   - At execution time you can provide custom domain name and cluster name, in order to set up these values use `-d` , `-c` and `-v` options.
   - It is important to mention that the minimum OpenShift version that allows SNO is 4.8.

3. 02_install_sno.sh - OpenShift 4 SNO Installation.
   - The installation is launched, there is no need of doing any extra step, just wait.
   - No parameters are required at execution time.
   - The install script will go through all the required steps to set boot media, restart the SNO when required and wait until installation ends.

## Procedure Execution
1. Run 00_create_sno_infra.sh on the hypervisor.
Here you can find some examples:

   * SNO infrastructure deployment with custom domain and cluster name.

   `/root/00_create_sno_infra.sh -d=domtest.com -c=snolab`

2. ssh to the installer VM and run 01_pre_reqs_ipibm.sh.

   * SNO 4.8 deployment, with custom domain and cluster name.

   `/root/01_pre_reqs_sno.sh -d=domtest.com -c=testlab -v=4.8`

3. From the installer VM run 02_install_ipibm.sh

   * Run the SNO installation.

   `/root/02_install_sno.sh`
