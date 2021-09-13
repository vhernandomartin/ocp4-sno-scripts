#/bin/bash
SNO_VM=$1

function find_redfish_urls () {
for server in $(curl -s http://localhost:8000/redfish/v1/Systems/|jq -r '.Members[]."@odata.id"')
  do
    SERVERNAME=$(curl -s http://localhost:8000$server|jq -r '.Name')
    if [ "$SERVERNAME" = "${SNO_VM}" ]; then
      SERVERSYS=$server
      MANAGEID=$(curl -s http://localhost:8000$server|jq -r '.Links.ManagedBy[]."@odata.id"')
      VIRTUALMEDIA=$(curl -s http://localhost:8000$MANAGEID|jq -r '.VirtualMedia."@odata.id"')
      #echo "$SERVERNAME --> http://localhost:8000$server"
      #echo -e "\t\t\__ ManagerURL --> http://localhost:8000$MANAGEID"
      #echo -e "\t\t\__ VirtualMediaURL --> http://localhost:8000$VIRTUALMEDIA/Cd"
    else
      continue
    fi
  done
}

function get_insertmedia_url () {
  echo -e "curl -d '{\"Image\":\"http://localhost/rhcos-live.x86_64.iso\", \"Inserted\": true}' -H \"Content-Type: application/json\" -X POST http://localhost:8000$VIRTUALMEDIA/Cd/Actions/VirtualMedia.InsertMedia"
}

function get_ejectmedia_url () {
  echo -e "curl -d '{\"Image\":\"http://localhost/rhcos-live.x86_64.iso\", \"Inserted\": true}' -H \"Content-Type: application/json\" -X POST http://localhost:8000$VIRTUALMEDIA/Cd/Actions/VirtualMedia.EjectMedia"
}
function set_bootcd () {
  echo -e "curl -X PATCH -H 'Content-Type: application/json' -d '{\"Boot\": {\"BootSourceOverrideTarget\": \"Cd\", \"BootSourceOverrideMode\": \"UEFI\", \"BootSourceOverrideEnabled\": \"Continuous\"}}' http://localhost:8000$SERVERSYS"
}

function set_boothdd () {
  echo -e "curl -X PATCH -H 'Content-Type: application/json' -d '{\"Boot\": {\"BootSourceOverrideTarget\": \"Hdd\", \"BootSourceOverrideMode\": \"UEFI\", \"BootSourceOverrideEnabled\": \"Continuous\"}}' http://localhost:8000$SERVERSYS"
}

function reset_server () {
  echo -e "curl -d '{\"ResetType\":\"On\"}' -H \"Content-Type: application/json\" -X POST http://localhost:8000$SERVERSYS/Actions/ComputerSystem.Reset"
}

function poweroff_server () {
  echo -e "curl -d '{\"ResetType\":\"ForceOff\"}' -H \"Content-Type: application/json\" -X POST http://localhost:8000$SERVERSYS/Actions/ComputerSystem.Reset"
}

## MENU ##
if [[ -z "$@" ]]; then
  echo -e "Missing arguments, run the following for help: $0 --help "
  exit 1
fi

for i in "$@"; do
  case $i in
    -h=*|--help=*)
    echo -e "\n+ Usage: $0 -n|--servername=<SNO_MASTER_SERVER> [-e|--ejectmedia] [-i|--insermedia] [-c|--setcdrom] [-d|--setdisk] [-r|--resetserver] [-p|--poweroff]"
    echo -e "[-n|--servername] SNO server name."
    echo -e "[-e|--ejectmedia] Get the url to eject media."
    echo -e "[-i|--insertmedia] Get the url to insert media."
    echo -e "[-c|--setcdrom] Get the url to set cdrom as booting device."
    echo -e "[-d|--setdisk] Get the url to set Hdd as booting device."
    echo -e "[-r|--resetserver] Get the url to reset a server."
    echo -e "[-p|--poweroff] Get the url to Power off a server."
    exit 0
    ;;
    -n=*|--servername=*)
    SNO_VM="${i#*=}"
    shift
    ;;
    -e|--ejectmedia)
    find_redfish_urls $SNO_VM
    get_ejectmedia_url $VIRTUALMEDIA
    ;;
    -i|--insertmedia)
    find_redfish_urls $SNO_VM
    get_insertmedia_url $VIRTUALMEDIA
    ;;
    -c|--setcdrom)
    find_redfish_urls $SNO_VM
    set_bootcd $SERVERSYS
    ;;
    -d|--setdisk)
    find_redfish_urls $SNO_VM
    set_boothdd $SERVERSYS
    ;;
    -r|--resetserver)
    find_redfish_urls $SNO_VM
    reset_server $SERVERSYS
    ;;
    -p|--poweroff)
    find_redfish_urls $SNO_VM
    poweroff_server $SERVERSYS
    ;;
    *)
    echo -e "\n+ Usage: $0 -n|--servername=<SNO_MASTER_SERVER> [-e|--ejectmedia] [-i|--insermedia] [-c|--setcdrom] [-d|--setdisk] [-r|--resetserver] [-p|--poweroff]"
    echo -e "[-n|--servername] SNO server name."
    echo -e "[-e|--ejectmedia] Get the url to eject media."
    echo -e "[-i|--insertmedia] Get the url to insert media."
    echo -e "[-c|--setcdrom] Get the url to set cdrom as booting device."
    echo -e "[-d|--setdisk] Get the url to set Hdd as booting device."
    echo -e "[-r|--resetserver] Get the url to reset a server."
    echo -e "[-p|--poweroff] Get the url to Power off a server."
    exit 1
  esac
done

if [[ -z "$DOMAIN" ]]; then
  DOMAIN=example.com
fi
if [[ -z "$CLUSTER_NAME" ]]; then
  CLUSTER_NAME=lab
fi

## MENU ##

#find_redfish_urls $SNO_VM
#get_insertmedia_url $VIRTUALMEDIA
#set_bootcd $SERVERSYS
#reset_server $SERVERSYS
