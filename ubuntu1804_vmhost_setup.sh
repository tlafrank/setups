#!/bin/bash
#Based upon the instructions at https://linuxconfig.org/install-and-set-up-kvm-on-ubuntu-18-04-bionic-beaver-linux
#This file is for actions carried out on the KVM host to support virtualisation.
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


function addNFSMount {
  
  #yum -y install nfs-utils.x86_64
  apt -y install nfs-common

  read -p 'IP Address of host: ' ipAddress
  read -p 'Directory on host: ' hostDir
  read -e -p 'Location to mount: ' mountPoint
  
  echo "$ipAddress:$hostDir $mountPoint nfs defaults 0 2" >> /etc/fstab

  mount -a
  case $? in 
    0) echo -e "[ ${GREEN}SUCCESS${NC} ] Mount successfully started";;
    *) echo -e "[ ${RED}FAILURE${NC} ] Mount was not successfully started";;
  esac
}


#Creates a new VM from an ISO file.
function new_vm {
  #This can be done, but is rather pointless as you need a graphical interface to undertake the installation
  
  #When accessing the remote VM's craphical interface, ensure that the VM's 'Display VNC' hardware type is set to VNC server.
  read -p 'Name of new VM: ' vmName
  read -p 'Number of virtual CPUs to allocate: ' vmCPU
  read -p 'RAM to allocate (Gb): ' vmRAM
  read -p 'Storage volume size (Gb): ' vmHDD
  read -e -p 'ISO installation file: ' isoFile

  vmRAM=$(expr 1024 \* $vmRAM)

  echo 'virt-install --name=$vmName --vcpus=$vmCPU --memory=$vmRAM --cdrom=$isoFile --disk size=$vmHDD,path=/var/lib/libvirt/images/$vmName.img'

  virt-install --name=$vmName \
  --vcpus=$vmCPU \
  --memory=$vmRAM \
  --cdrom=$isoFile \
  --disk size=$vmHDD,path=/var/lib/libvirt/images/$vmName.img
}

#Clones an existing VM
function virt-clone {

  read -p 'What is the original VM to clone: ' originalDomain
  read -p 'What is the new VM name: ' newDomain

  virt-clone --original $originalDomain --name $newDomain --auto-clone
  if [ $? == 0 ]; then
    echo -e "[ ${GREEN}SUCCESS${NC} ] $newDomain was created"
  else
    echo -e '[ ${RED}FAILURE{NC} ] A non-zero error code was thrown when attempting to clone' $originalDomain
  fi
}

function network {

  PS3="Choice: "

  select opt in \
    'Create bridge'\
    'Configure interface'\
    'TBA'
  do
    case $opt in
      'Create bridge')
        read -p 'Interface name (br-X): ' ifaceName
        read -p 'Interface IP (10.0.5.X/24): ' ifaceAddresses
        read -p 'Interface Gateway (10.0.5.1): ' ifaceGateway
        nmcli conn add ifname $ifaceName type bridge con-name $ifaceName
        nmcli conn modify id $ifaceName +ipv4.method manual +ipv4.addresses $if$

      if [ $ifaceGateway == '' ]; then
          nmcli conn modify id $ifaceName +ipv4.gateway $ifaceGateway
        fi
        nmcli conn up id $ifaceName
      ;;
      'Configure interface')
        select ifaceName in $(nmcli -t device | awk -F: '{print $1}');
        do
    echo 'Updating' $ifaceName
          read -p 'IP Address (10.0.5.x/24): ' $ifaceAddress
          nmcli conn modify id $ifaceName +ipv4.address $ifaceAddress +ipv4.method manual
          nmcli connection up $ifaceName
        done
      ;;
      'TBA') networkTBA;;
      *)
        exit;
        break;
     ;;
    esac
  done
}

function cifs {
  apt install cifs-utils

  #Configure shares
  echo "Do you wish to add shares permanently to fstab?"
  select continue in "Yes" "No"; do
    case $continue in
      Yes )
        #Get details to add the share to fstab
        read -p "What is the address: //" address
        read -p "Where is this to be mounted: " mount
        read -p "What is the username: " username

        mkdir $mount
        echo "//"$address" "$mount" cifs username="$username" 0 0 " >> /etc/fstab

        mount -a

        echo "Do you wish to add another share?"
        echo "1) Yes"
        echo "2) No"
        ;;
      No ) break;;
    esac
  done
}

function update {
  apt -y update
  apt -y upgrade
}

function kvm {
  #KVM
  read -p "Install KVM? " continue
  if [ $continue = "y" ]; then
    apt-get -y install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager

    #Add the current user to the relevant groups
    adduser $SUDO_USER libvirt
    adduser $SUDO_USER libvirt-qemu

    #Enable bash completion for virsh
    cp ./virsh-bash-completion /etc/bash_completion.d/

    #Configure the network
    temp=$(mktemp /tmp/netplanXXXX.yaml)
    mv /etc/netplan/01-network-manager-all.yaml $temp
    echo "Original netplan config moved to "$temp
cat > /etc/netplan/01-network-manager-all.yaml <<EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eno1:
      dhcp4: no
  bridges:
    br0:
      interfaces:
        - eno1
      dhcp4: no
      addresses: [10.0.11.10/24]
      gateway4: 10.0.11.1
      nameservers:
        addresses: [8.8.8.8]
EOF
    #Restart netplan
    netplan generate
    if [ $? = 0 ]; then
      netplan apply 2> /dev/null
      netplan apply 2> /dev/null #Every second execution throws an error for some reason.
    else
      echo "An error occurred whilst generating the netplan config file."
    fi

    #Fix routes
    ip route del default

    #Configure libvirt's default network
    virsh net-undefine default
    virsh net-define network.xml

    #Restart
    #Could update to remove the requirement to reboot
    echo 'Please restart the system'
  fi
}


#Check that the script is being run as SUDO.
if [ "root" = $USER ]; then
  echo 'Script is running as SUDO, as expected.'

  PS3="Choice: "

  select opt in \
    'Update/Upgrade'\
    'Install KVM'\
    'Create VM from ISO'\
    'Clone VM'\
    'Install OpenVPN Client'\
    'Configure CIFS'\
    'Setup networking'\
    'Exit'
  do
    case $opt in
      'Update/Upgrade') update;;
      'Install KVM') kvm;;
      'Clone VM') virt-clone;;
      'Create VM from ISO') new_vm;;
      'Configure CIFS') cifs;;
      'Setup networking') network;;
      *)
        exit;
        break;
      ;;
    esac
  done
else
  echo 'Script is not running as SUDO (required). Exiting with no changes.'
fi
