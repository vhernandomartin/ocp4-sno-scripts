#!/bin/bash

## ENV VARS ##
LIBVIRT_HOME=/var/lib/libvirt
LIBVIRT_IMGS=$LIBVIRT_HOME/images
INSTALLER_VM=sno-installer
SNO_VM=sno-master
SNO_NET=lab-sno
#SNO_CIDR=192.168.119.1/24
OCP_DOMAIN=lab.example.com
ID_RSA_PUB=$(cat /root/.ssh/id_rsa.pub)
SNO_IPV4_IPROUTE=192.168.119.1
SNO_IPV4_PREFIX=24
SNO_IPV6_IPROUTE=2620:52:0:1001::1
SNO_IPV6_PREFIX=64
IPV4_RANGE_START=192.168.119.2
IPV4_RANGE_END=192.168.119.254
IPV6_RANGE_START=2620:52:0:1001::2
IPV6_RANGE_END=2620:52:0:1001::ffff
SNO_IPV4_INSTALLER_IP=192.168.119.100
SNO_IPV6_INSTALLER_IP=2620:52:0:1001::100
SNO_IPV4=192.168.119.20
SNO_IPV6=2620:52:0:1001::20
SNO_MAC_IPV4=aa:aa:aa:aa:bc:01
SNO_MAC_IPV6=00:03:00:01:aa:aa:aa:aa:bc:01
INSTALLER_MAC_IPV4=aa:aa:aa:aa:bc:00
SNO_CIDR_IPV4=192.168.119.1/24
SNO_CIDR_IPV6=2620:52:0:1001::1/64

## ENV VARS ##

## FUNCTIONS ##
function set_vars () {
  OCP_DOMAIN=${CLUSTER_NAME}.${DOMAIN}
  IP_TYPE=$1
  if [ "${IP_TYPE}" = "ipv4" ]; then
    echo -e "+ Setting vars for a ipv4 cluster."
    echo -e "+ The network range configured is: ${SNO_CIDR_IPV4}"
    IPV="ip4" #?
    IPFAMILY="ipv4" #ok
    SNO_CIDR=${SNO_CIDR_IPV4}
    IPROUTE=${SNO_IPV4_IPROUTE} #ok
    IPPREFIX=${SNO_IPV4_PREFIX} #ok
    INSTALLER_IP=${SNO_IPV4_INSTALLER_IP} #ok
    SNO_IP=${SNO_IPV4} #ok
    HOSTIDMAC="host mac" #ok
    IP_RANGE_START=${IPV4_RANGE_START} #ok
    IP_RANGE_END=${IPV4_RANGE_END} #ok
    SNO_MAC=${SNO_MAC_IPV4} #ok
  elif [ "${IP_TYPE}" = "ipv6" ]; then
    echo -e "+ Setting vars for a ipv6 cluster."
    echo -e "+ The network range configured is: ${SNO_CIDR_IPV6}"
    IPV="ip6" #?
    IPFAMILY="ipv6" #ok
    SNO_CIDR=${SNO_CIDR_IPV6}
    IPROUTE=${SNO_IPV6_IPROUTE} #ok
    IPPREFIX=${SNO_IPV6_PREFIX} #ok
    INSTALLER_IP=${SNO_IPV6_INSTALLER_IP} #ok
    SNO_IP=${SNO_IPV6} #ok
    HOSTIDMAC="host id" #ok
    IP_RANGE_START=${IPV6_RANGE_START} #ok
    IP_RANGE_END=${IPV6_RANGE_END} #ok
    SNO_MAC=${SNO_MAC_IPV6} #ok
    echo -e "+ Setting net.ipv6 required values..."
    sysctl -w net.ipv6.conf.all.accept_ra=2
    sysctl -w net.ipv6.conf.all.forwarding=1
  else
    echo -e "+ A valid network type value should be provided: ipv4/ipv6."
  fi
}

function check_binary () {
  BINARY=$1
  # Check whether a specific binary exists or not
  if [ "$(which $BINARY)" = "" ]; then
    echo -e "\n+ $BINARY is not present in the $PATH or it is not installed"
    echo -e "+ Look for $BINARY in custom PATHs or try to install it with dnf or yum"
    exit 1
  else
    echo -e "\n+ $BINARY is already installed: $(which $BINARY)"
  fi
}

function create_images () {
# First of all check if the CentOS 8 Generic Cloud image is already downloaded
CENTOS_IMGS=$(ls $LIBVIRT_IMGS/CentOS-8-GenericCloud-8.*)
if [ -f "$CENTOS_IMGS" ]; then
  echo "+ There is already an image, proceeding with that image..."
  echo -e "\t\__>$CENTOS_IMGS"
else
  echo "+ No CentOS image found, downloading a new image..."
  curl https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2 > $LIBVIRT_IMGS/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2
  chown qemu:qemu $LIBVIRT_IMGS/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2
fi

# Check whether qemu-img binary exists or not
if [ "$(which qemu-img)" = "" ]; then
  echo -e "\n+ qemu-img is not present in the $PATH or it is not installed"
  exit 1
else
  echo -e "\n+ qemu-img is already installed: $(which qemu-img)"
fi
# Creating disk images for installer and master/worker node for SNO
qemu-img create -f qcow2 -F qcow2 -b ${LIBVIRT_IMGS}/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2 ${LIBVIRT_IMGS}/${INSTALLER_VM}.qcow2
qemu-img create -f qcow2 ${LIBVIRT_IMGS}/${SNO_VM}.qcow2 50G
}

function create_cloud_init_config () {
# We need to create a temp dir to make the custom cloud init scripts and iso
echo -e "\n+ Creating temp dir and cloud-init config..."
mkdir /root/$INSTALLER_VM && cd /root/$INSTALLER_VM

# meta-data file
cat << EOF > meta-data
instance-id: ${INSTALLER_VM}
local-hostname: ${INSTALLER_VM}
EOF

#user-data file
cat << EOF > user-data
#cloud-config
preserve_hostname: False
hostname: ${INSTALLER_VM}
fqdn: ${INSTALLER_VM}.${OCP_DOMAIN}
user: test
password: test
chpasswd: {expire: False}
ssh_pwauth: True
ssh_authorized_keys:
  - ${ID_RSA_PUB}
chpasswd:
  list: |
     root:test
     test:test
  expire: False
runcmd:
- sed -i -e 's/^.*\(ssh-rsa.*\).*$/\1/' /root/.ssh/authorized_keys
EOF

# Time to create the new image including user-data and meta-data, this will be used to inject the cloud-init customizations.
genisoimage -output ${INSTALLER_VM}.iso -volid cidata -joliet -rock user-data meta-data
cp ${INSTALLER_VM}.iso ${LIBVIRT_IMGS}
}

function networks () {
echo -e "\n+ Creating network with nmcli..."
#nmcli conn add type bridge con-name ${SNO_NET} ifname ${SNO_NET} autoconnect no ip4 ${SNO_CIDR} +ipv4.dns-priority 100 +ipv6.method disabled +ipv6.dns-priority 100 +bridge.forward-delay 2 +bridge.multicast-hash-max 512
#nmcli conn show|grep ${SNO_NET}

echo -e "\n+ Defining virsh network and applying configuration..."
cat << EOF > lab-sno-network.xml
<network>
  <name>${SNO_NET}</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='${SNO_NET}' stp='on' delay='0'/>
  <mac address='52:54:00:eb:3a:aa'/>
  <domain name='${SNO_NET}'/>
  <dns>
    <host ip='${SNO_IP}'>
      <hostname>${SNO_VM}</hostname>
      <hostname>api-int.${OCP_DOMAIN}</hostname>
      <hostname>api.${OCP_DOMAIN}</hostname>
      <hostname>apps</hostname>
      <hostname>console-openshift-console.apps.${OCP_DOMAIN}</hostname>
      <hostname>oauth-openshift.apps.${OCP_DOMAIN}</hostname>
      <hostname>prometheus-k8s-openshift-monitoring.apps.${OCP_DOMAIN}</hostname>
      <hostname>canary-openshift-ingress-canary.apps.${OCP_DOMAIN}</hostname>
      <hostname>assisted-service-open-cluster-management.apps.${OCP_DOMAIN}</hostname>
      <hostname>assisted-service-assisted-installer.apps.${OCP_DOMAIN}</hostname>
    </host>
  </dns>
  <ip family='${IPFAMILY}' address='${IPROUTE}' prefix='${IPPREFIX}'>
    <dhcp>
      <range start='${IP_RANGE_START}' end='${IP_RANGE_END}'/>
      <${HOSTIDMAC}='${SNO_MAC}' name='${SNO_VM}' ip='${SNO_IP}'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define ${SNO_NET}-network.xml
virsh net-autostart ${SNO_NET}
virsh net-start ${SNO_NET}
}

function create_vms () {
# Check whether virt-install binary exists or not
if [ "$(which virt-install)" = "" ]; then
  echo -e "\n+ virt-install is not present in the $PATH or it is not installed"
  exit 1
else
  echo -e "\n+ virt-install is already installed: $(which virt-install)"
fi

virt-install --virt-type=kvm --name=${INSTALLER_VM} --ram 8192 --vcpus 8 --hvm --network network=default,model=virtio,mac=aa:aa:aa:aa:cc:00 --network network=${SNO_NET},model=virtio,mac=${INSTALLER_MAC_IPV4} --disk ${LIBVIRT_IMGS}/${INSTALLER_VM}.qcow2,device=disk,bus=virtio,format=qcow2 --disk ${LIBVIRT_IMGS}/${INSTALLER_VM}.iso,device=cdrom --os-type Linux --os-variant rhel8.0 --graphics none --import --noautoconsole

sleep 5

virt-install --virt-type=kvm --name=${SNO_VM} --ram 16384 --vcpus 8 --hvm --network network=${SNO_NET},model=virtio,mac=${SNO_MAC_IPV4} --disk ${LIBVIRT_IMGS}/${SNO_VM}.qcow2,device=disk,bus=virtio,format=qcow2 --os-type Linux --os-variant rhel8.0 --graphics none --import --noautoconsole
virsh destroy ${SNO_VM}

#echo -e "\n+ Waiting 60seg to let the ${INSTALLER_VM} boot properly..."
#sleep 60
#scp /root/.ssh/id_rsa* root@192.168.119.15:/root/.ssh/.
}

function config_dns_hosts () {
  check_binary virsh
  while [[ ${IP} = "" ]]
  do
    IP=$(virsh net-dhcp-leases ${SNO_NET} |grep ${INSTALLER_MAC_IPV4}|tail -1|awk '{print $5}'|cut -d "/" -f 1)
    echo -e "+ Waiting to grab an IP from DHCP..."
    sleep 5
  done
  echo -e "+ IP already assigned: ${IP}"
  virsh net-update ${SNO_NET} add dns-host "<host ip='${IP}'> <hostname>${INSTALLER_VM}</hostname> <hostname>${INSTALLER_VM}.${OCP_DOMAIN}</hostname> </host>" --live --config
  copy_id_rsa ${IP}
  copy_install_files ${IP}
  set_etc_hosts ${IP}
}

function copy_id_rsa () {
  IP=$1
  echo -e "\n+ Waiting 90seg to let the ${INSTALLER_VM} boot properly..."
  sleep 90
  scp /root/.ssh/id_rsa* root@[${IP}]:/root/.ssh/.
}

function copy_install_files () {
  IP=$1
  echo -e "\n+ Copying install files to ${INSTALLER_VM} with IP: ${IP} ..."
  scp /root/01_pre_reqs_sno.sh /root/02_install_sno.sh /root/find_redfish_host.sh root@[${IP}]:/root/.
}

function set_etc_hosts () {
  IP=$1
  echo -e "\n+ Setting ${SNO_IP} in the ${INSTALLER_VM} /etc/hosts ..."
  ssh root@${IP} echo "${SNO_IP} api.${OCP_DOMAIN} api-int.${OCP_DOMAIN} >> /etc/hosts"
}
## FUNCTIONS ##

## MENU ##
if [[ -z "$@" ]]; then
  echo -e "Missing arguments, run the following for help: $0 --help "
  exit 1
fi

for i in "$@"; do
  case $i in
    -h=*|--help=*)
    echo -e "\n+ Usage: $0 -d=<DOMAIN_NAME> -c=<CLUSTER_NAME>"
    echo -e "Provide a valid domain name, if not present example.com will be set as the default domain"
    echo -e "Provide a valid cluster name, if not present lab will be set as the default cluster name"
    exit 0
    ;;
    -n=*|--net=*)
    IP_TYPE="${i#*=}"
    shift
    ;;
    -d=*|--domain=*)
    DOMAIN="${i#*=}"
    shift
    ;;
    -c=*|--clustername=*)
    CLUSTER_NAME="${i#*=}"
    shift
    ;;
    *)
    echo -e "\n+ Usage: $0 -d=<DOMAIN_NAME> -c=<CLUSTER_NAME>"
    echo -e "Provide a valid domain name, if not present example.com will be set as the default domain"
    echo -e "Provide a valid cluster name, if not present lab will be set as the default cluster name"
    exit 1
  esac
done

if [[ -z "$IP_TYPE" ]]; then
  IP_TYPE=ipv4
fi
if [[ -z "$DOMAIN" ]]; then
  DOMAIN=example.com
fi
if [[ -z "$CLUSTER_NAME" ]]; then
  CLUSTER_NAME=lab
fi

## MENU ##

## MAIN ##
set_vars ${IP_TYPE}
create_images
create_cloud_init_config
networks
create_vms
config_dns_hosts
## MAIN ##
