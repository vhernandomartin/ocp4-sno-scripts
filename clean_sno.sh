#!/bin/bash

## ENV VARS ##
LIBVIRT_HOME=/var/lib/libvirt
DNSMASQ_HOME=$LIBVIRT_HOME/dnsmasq
LIBVIRT_IMGS=$LIBVIRT_HOME/images
INSTALLER_VM=sno-installer
SNO_VM=sno-master
SNO_NET=lab-sno
SNO_CIDR=192.168.119.1/24
OCP_DOMAIN=lab.example.com
ID_RSA_PUB=$(cat /root/.ssh/id_rsa.pub)
## ENV VARS ##

echo -e "+ Deleting VMs..."
virsh destroy ${SNO_VM} ; virsh undefine ${SNO_VM}
virsh destroy ${INSTALLER_VM} ; virsh undefine ${INSTALLER_VM}

echo -e "\n+ Deleting Networks..."
virsh net-destroy ${SNO_NET}
virsh net-undefine ${SNO_NET}
nmcli conn delete ${SNO_NET}
DNSMASQ_FILES=$(ls $DNSMASQ_HOME/$SNO_NET.*|wc -l)
if [ $DNSMASQ_FILES -gt 0 ]; then
  echo -e "\n+ There are some networks already configured in dnsmasq ($DNSMASQ_FILES), deleting those files..."
  rm -fR ${DNSMASQ_HOME}/${SNO_NET}.*
else
  echo -e "\n+ No network files for $SNO_NET network..."
fi

echo -e "\n+ Removing VM disks..."
rm ${LIBVIRT_IMGS}/${SNO_VM}.qcow2 && rm ${LIBVIRT_IMGS}/${INSTALLER_VM}.qcow2 && rm ${LIBVIRT_IMGS}/${INSTALLER_VM}.iso

if [ -d /root/${INSTALLER_VM} ]; then
  echo -e "\n+ The path /root/${INSTALLER_VM} exists, deleting it..."
  rm -fR /root/${INSTALLER_VM}
else
  echo -e "\n+ The path /root/${INSTALLER_VM} doesn't exists, nothing to do"
fi
