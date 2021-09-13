#!/bin/bash

## VARS ##

SNO_VM=sno-master
SNO_IPV4_IPROUTE=192.168.119.1
SNO_IPV6_IPROUTE="[2620:52:0:1001::1]"
SNO_CIDR_IPV4=192.168.119.0/24
SNO_CIDR_IPV6=2620:52:0:1001::/64
SNO_CNET_CIDR_IPV4=10.132.0.0/14
SNO_SNET_CIDR_IPV4=172.30.0.0/16
SNO_CNET_CIDR_IPV6=fd01::/48
SNO_SNET_CIDR_IPV6=fd02::/112
DEF_CNET_HOST_PREFIX_IPV4=23
DEF_CNET_HOST_PREFIX_IPV6=64
## VARS ##

## FUNCTIONS ##

function set_vars () {
  MINOR_VERSION=$(echo ${OCP4_VER}|cut -d "." -f 2)
  IP_TYPE=$1
  if [ "${IP_TYPE}" = "ipv4" ]; then
    echo -e "+ Setting vars for a ipv4 cluster."
    NET_TYPE=inet
    SNO_IPROUTE=$SNO_IPV4_IPROUTE #ok
    SUSHY_EMULATOR_LISTEN_IP="0.0.0.0" #ok
    SNO_CIDR=$SNO_CIDR_IPV4 #ok
    SNO_CNET_CIDR=$SNO_CNET_CIDR_IPV4 #ok
    SNO_SNET_CIDR=$SNO_SNET_CIDR_IPV4 #ok
    DEF_CNET_HOST_PREFIX=$DEF_CNET_HOST_PREFIX_IPV4 #ok
  elif [ "${IP_TYPE}" = "ipv6" ]; then
    echo -e "+ Setting vars for a ipv6 cluster."
    NET_TYPE=inet6
    SNO_IPROUTE=$SNO_IPV6_IPROUTE #ok
    SUSHY_EMULATOR_LISTEN_IP="::" #ok
    SNO_CIDR=$SNO_CIDR_IPV6 #ok
    SNO_CNET_CIDR=$SNO_CNET_CIDR_IPV6 #ok
    SNO_SNET_CIDR=$SNO_SNET_CIDR_IPV6 #ok
    DEF_CNET_HOST_PREFIX=$DEF_CNET_HOST_PREFIX_IPV6 #ok
  else
    echo -e "+ A valid network type value should be provided: ipv4/ipv6."
  fi
}

function pre_reqs () {
# Sushy service
echo -e "+ Configuring Sushy service..."

cat << EOF > /usr/lib/systemd/system/sushy.service
[Unit]
Description=Sushy Libvirt emulator
After=syslog.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sushy-emulator --config /etc/sushy.conf
StandardOutput=syslog
StandardError=syslog
EOF

cat << EOF > /etc/sushy.conf
SUSHY_EMULATOR_LISTEN_IP = u'${SUSHY_EMULATOR_LISTEN_IP}'
SUSHY_EMULATOR_LISTEN_PORT = 8000
SUSHY_EMULATOR_SSL_CERT = None
SUSHY_EMULATOR_SSL_KEY = None
SUSHY_EMULATOR_OS_CLOUD = None
SUSHY_EMULATOR_LIBVIRT_URI = u'qemu+ssh://root@${SNO_IPROUTE}/system'
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = True
SUSHY_EMULATOR_BOOT_LOADER_MAP = {
    u'UEFI': {
        u'x86_64': u'/usr/share/OVMF/OVMF_CODE.secboot.fd',
        u'aarch64': u'/usr/share/AAVMF/AAVMF_CODE.fd'
    },
    u'Legacy': {
        u'x86_64': None,
        u'aarch64': None
    }
}
EOF

echo -e "\n+ Installing some required packages..."
dnf clean all && sleep 30 && dnf -y install pkgconf-pkg-config libvirt-devel gcc python3-libvirt python3 git python3-netifaces
pip3 install sushy-tools
systemctl enable --now sushy && systemctl status sushy

echo -e "\n+ Creating the SNO install-config.yaml file..."
cat << EOF > install-config.yaml
apiVersion: v1
baseDomain: ${DOMAIN}
networking:
  networkType: OVNKubernetes
  machineNetwork:
  - cidr: ${SNO_CIDR}
  clusterNetwork:
  - cidr: ${SNO_CNET_CIDR}
    hostPrefix: ${DEF_CNET_HOST_PREFIX}
  serviceNetwork:
  - ${SNO_SNET_CIDR}
metadata:
  name: ${CLUSTER_NAME}
compute:
- name: worker
  replicas: 0
controlPlane:
  name: master
  replicas: 1
platform:
  none: {}
bootstrapInPlace:
  installationDisk: /dev/vda
EOF

echo -e "\n+ Creating the openshift_pull.json file..."
cat << EOF > openshift_pull.json
<INSERT_HERE_YOUR_PULL_SECRETS>
EOF

}

function lab_installation () {
echo -e "\n+ Patching install-config.yaml..."
ssh-keyscan -H ${SNO_IPROUTE} >> ~/.ssh/known_hosts
echo -e "Host=*\nStrictHostKeyChecking=no\n" > ~/.ssh/config
PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
echo -e "pullSecret: |\n  $PULLSECRET" >> /root/install-config.yaml
SSHKEY=$(cat /root/.ssh/id_rsa.pub)
echo -e "sshKey: |\n  $SSHKEY" >> /root/install-config.yaml

echo "\n+ Installing libvirt and other required tools..."
dnf -y install libvirt-libs libvirt-client ipmitool mkisofs tmux make git bash-completion
dnf -y install python36
export CRYPTOGRAPHY_DONT_BUILD_RUST=1
pip3 install -U pip
pip3 install python-ironicclient --ignore-installed PyYAML

echo "\n+ Installing httpd and podman..."
yum install -y httpd podman jq
systemctl enable httpd --now

echo -e "\n+ Downloading oc client and installer..."
curl -k https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OCP4_VER}/openshift-client-linux.tar.gz > oc.tar.gz
tar zxvf oc.tar.gz
cp oc /usr/local/bin
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest-${OCP4_VER}/openshift-install-linux.tar.gz > openshift-install-linux.tar.gz
tar zxvf openshift-install-linux.tar.gz
mkdir /root/bin
cp openshift-install /root/bin
curl $(./openshift-install coreos print-stream-json  | jq .architectures.x86_64.artifacts.metal.formats.iso.disk.location|sed 's/"//g') > rhcos-live.x86_64.iso
}

## FUNCTIONS ##

## FUNCTIONS ##

## MENU ##
if [[ -z "$@" ]]; then
  echo -e "Missing arguments, run the following for help: $0 --help "
  exit 1
fi

for i in "$@"; do
  case $i in
    -h=*|--help=*)
    echo -e "\n+ Usage: $0 -d=<DOMAIN_NAME> -c=<CLUSTER_NAME>  -v=<OCP4_VERSION>"
    echo -e "Provide a valid domain name, if not present example.com will be set as the default domain"
    echo -e "Provide a valid cluster name, if not present lab will be set as the default cluster name"
    echo -e "OpenShift 4 minor version only allowed, 4.8, 4.9... Versions < 4.8 are not valid "
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
    -v=*|--version=*)
    OCP4_VER="${i#*=}"
    shift
    ;;
    *)
    echo -e "\n+ Usage: $0 -d=<DOMAIN_NAME> -c=<CLUSTER_NAME> -v=<OCP4_VERSION>"
    echo -e "Provide a valid domain name, if not present example.com will be set as the default domain"
    echo -e "Provide a valid cluster name, if not present lab will be set as the default cluster name"
    echo -e "OpenShift 4 minor version only allowed, 4.8, 4.9... Versions < 4.8 are not valid "
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
pre_reqs
lab_installation
#redfish_urls $SNO_VM

## MAIN ##
