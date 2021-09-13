#!/bin/bash

## VARS ##

SNO_VM=sno-master
SNO_NET=lab-sno
SNO_CIDR_IPV4=192.168.119.0/24
SNO_CIDR_IPV6=2620:52:0:1001::/64
SNO_IPV4=192.168.119.20
SNO_IPV6=2620:52:0:1001::20
IP_TYPE=ipv4

## VARS ##

## FUNCTIONS ##

function set_vars () {
  #OCP_DOMAIN=${CLUSTER_NAME}.${DOMAIN}
  IP_TYPE=$1
  if [ "${IP_TYPE}" = "ipv4" ]; then
    echo -e "+ Setting vars for a ipv4 cluster."
    echo -e "+ The network range configured is: ${SNO_CIDR_IPV4}"
    SNO_IP=${SNO_IPV4} #ok
  elif [ "${IP_TYPE}" = "ipv6" ]; then
    echo -e "+ Setting vars for a ipv6 cluster."
    echo -e "+ The network range configured is: ${SNO_CIDR_IPV6}"
    SNO_IP=${SNO_IPV6} #ok
  else
    echo -e "+ A valid network type value should be provided: ipv4/ipv6."
  fi
}

function install_sno () {
SNO_VM=$1
echo -e "+ Creating ignition config..."
mkdir ocp
cp install-config.yaml ocp/.
./openshift-install --dir=ocp create single-node-ignition-config
cp ocp/bootstrap-in-place-for-live-iso.ign iso.ign

echo -e "\n+ Adding the ignition config to the CoreOS installer image..."
COREOSINST="podman run --privileged --rm -v /dev:/dev -v /run/udev:/run/udev -v ${PWD}:/data -w /data quay.io/coreos/coreos-installer:release"
$COREOSINST iso ignition embed -fi iso.ign rhcos-live.x86_64.iso
cp rhcos-live.x86_64.iso /var/www/html/.
restorecon -Frvv /var/www/html/rhcos-live.x86_64.iso

echo -e "\n+ Setting the rhcos installation media as the boot device..."
INSERT_MEDIA=$(/root/find_redfish_host.sh -n=$SNO_VM -i|bash)
$INSERT_MEDIA
echo -e "\n+ Setting the Cd as the Virtual Media boot device..."
SETCD_BOOT_MEDIA=$(/root/find_redfish_host.sh -n=$SNO_VM -c|bash)
$SETCD_BOOT_MEDIA
echo -e "\n+ Rebooting the $SNO_VM server..."
REBOOT_SERVER=$(/root/find_redfish_host.sh -n=$SNO_VM -r|bash)
$REBOOT_SERVER
echo -e "+ Waiting for server to be up and running..."

counter=1
while [[ "${PING}" -lt "1" ]]
do
  PING=$(ssh core@${SNO_IP} uname -a|grep Linux|wc -l)
  echo -e "+ Waiting for server ${SNO_VM} with ip ${SNO_IP}..."
  sleep 5
  echo -e "Try $counter..."
  if [ $counter = 12 ]; then
    exit 1
  fi
  let counter++
done

echo -e "\n+ Waiting for server reboot after the initial rhcos deployment..."
PING=1
counter=1
while [[ "${PING}" -ne "0" ]]
do
  PING=$(ssh core@${SNO_IP} uname -a|grep Linux|wc -l)
  echo -e "+ Waiting for server ${SNO_VM} with ip ${SNO_IP} to be rebooted..."
  sleep 5
  echo -e "Try $counter..."
  if [ $counter = 150 ]; then
    exit 1
  fi
  let counter++
done
echo -e "+ Server rebooted successfully!"
echo -e "\n+ Forcing shutdown on server ${SNO_VM}..."
POWEROFF_SERVER=$(/root/find_redfish_host.sh -n=$SNO_VM -p|bash)
$POWEROFF_SERVER
echo -e "\n+ Ejecting installation media from device..."
EJECT_MEDIA=$(/root/find_redfish_host.sh -n=$SNO_VM -e|bash)
$EJECT_MEDIA
echo -e "\n+ Setting Hdd as the boot device..."
SETHDD_BOOT_MEDIA=$(/root/find_redfish_host.sh -n=$SNO_VM -d|bash)
$SETHDD_BOOT_MEDIA
echo -e "\n+ Starting the server ${SNO_VM}..."
REBOOT_SERVER=$(/root/find_redfish_host.sh -n=$SNO_VM -r|bash)
$REBOOT_SERVER
echo -e "\n+ Waiting for cluster installation completion"
/root/openshift-install --dir=ocp wait-for install-complete
}

## FUNCTIONS ##


## MAIN ##
set_vars ${IP_TYPE}
install_sno $SNO_VM

## MAIN ##
