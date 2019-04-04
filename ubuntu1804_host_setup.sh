#!/bin/bash

#Constants
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"


function main() {
  #Check that the script is being run as SUDO.
  if [ "root" = $USER ]; then
    clear
    echo 'Script is running as SUDO, as expected. xx'

    PS3="Choice: "

    select opt in \
      'KEEP - Install KVM'\
      'Install OpenVPN Client'\
      'Install OpenVPN Server'\
      'Configure CIFS'\
      'Setup NFS Server'\
      'KEEP - Add desktop icon'\
      'KEEP - Install Sublime'\
      'Exit'
    do
      case $opt in
        'Install KVM') kvm;;
        'Install OpenVPN Client') openvpn_client;;
        'Install OpenVPN Server') openvpn_server;;
        'Configure CIFS') cifs;;
        'Add desktop icon') addDesktopIcon;;
        'Setup NFS Server') setupNFSServer;;
        'Install Sublime') install_sublime;;
        *)
          exit;
          break;
        ;;
      esac
    done
  else
    echo 'Script is not running as SUDO (required). Exiting with no changes.'
  fi
}


function kvm {
  #KVM
  read -p "Install KVM? " continue
  if [[ $continue =~ [yY] ]]; then
    apt-get -y install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager

    #Add the current user to the relevant groups
    adduser $SUDO_USER libvirt
    adduser $SUDO_USER libvirt-qemu

    #Enable bash completion for virsh
    cp ./helpers/virsh-bash-completion /etc/bash_completion.d/

    ### Configure the network  
    read -n 1 -p "Remove the libvirt default network? (y/n) " continue
    if [[ $continue =~ [yY] ]]; then
      #Configure libvirt's default network
      virsh net-undefine default
      #virsh net-define network.xml
    fi

    #Restart
    #Could update to remove the requirement to reboot
    echo 'Please restart the system'
  fi
}




function openvpn_server {

  #Get the external interface IP to use
  echo "Please select the VPN interface: "
  select ipAddress in $(ip addr | grep -Po 'inet \K[\d.]+') 
  do

    break;
  done

  #Install OpenVPN
  apt-get -y install openvpn

  #Configure the server

    #Check if the user wants all traffic to go via the VPN (default=off)
      #/etc/openvpn/server.conf
      #push "redirect-gateway def1 bypass-dhcp"

    #Set net.ipv4.ip_forward=1 (allow routing)


  #Configure certificates
  #Probably use a separate helper


  #Configure the firewall
  ufw allow openvpn
  ufw reload

  systemctl restart openvpn@server
}



#
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


function install_networkManager() {
  #

  apt-get -y install network-manager

  #Start NetworkManager
  systemctl start NetworkManager


  cat > /etc/netplan/01-network-manager-all.yaml <<EOF
network:
  version: 2
  renderer: NetworkManager
EOF
  #Restart netplan
  netplan generate
  if [ $? = 0 ]; then
    netplan apply 2> /dev/null
    netplan apply 2> /dev/null #Every second execution throws an error for some reason.
  else
    echo "An error occurred whilst generating the netplan config file."
  fi

  

}





function openvpn_client {
  apt install network-manager-openvpn-gnome openvpn-systemd-resolved

  #Not clear if this is required
  #apt install openvpn
}


#
function setupNFSServer {

  apt -y install nfs-kernel-server


  echo 'The folder to share will have its group, owner and permissions changed.'
  read -e -p 'Folder to share: ' shareFolder

  mkdir $shareFolder 2> /dev/null
  if [ $? -eq 0 ]; then
    echo 'Configuring permissions'
    chown nobody:nogroup $shareFolder
    chmod 777 $shareFolder  
  else
    echo 'The directory exists, folder permissions have not been modified'
    printf 'The seleced folder has the following permissions, owner and group: '
    ls -la $shareFolder | awk 'NR==2 {print $1,$3,$4}'
  fi

  read -p 'What subnet can access the folder (10.0.0.0/24): ' subnet
  echo "$shareFolder $subnet(rw,sync,no_subtree_check)" >> /etc/exports

  exportfs -a
  case $? in 
    0) echo -e "[ ${GREEN}SUCCESS${NC} ] NFS share exported";;
    *) echo -e "[ ${RED}FAILURE${NC} ] There was an error in running exportfs -a";;
  esac

  systemctl restart nfs-kernel-server

  echo "[   NOTE  ] Firewall configurationn may be required for some systems."

}


function add-repos {
  #For Ntop
  echo 'add repos'
 # add-apt-repository universe
  #wget http://apt-stable.ntop.org/18.04/all/apt-ntop-stable.deb
  #dpkg -i apt-ntop-stable.deb

  #apt install pfring nprobe ntopng ntopng-data n2disk cento nbox
}


function virtstuff {

  read -p 'What is the original VM to clone: ' originalDomain
  read -p 'What is the new VM name: ' newDomain

  virt-clone --original $originalDomain --name $newDomain --auto-clone
}



#Creates a desktop icon for a script
function addDesktopIcon {
  echo "Creating Desktop Icon"
  read -p 'Icon name: ' iconName
  read -e -p 'Path to script' scriptDir

}

function install_sublime {
  #Check if the sublime repo already exists
  if ! [[ -e /etc/apt/sources.list.d/sublime-text.list ]]; then
    echo -e "[ ${YELLOW}INFO${NC} ] Source for sublime does not currently exist"
    #Install GPG Key
    wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
    sudo apt-get -y install apt-transport-https
    echo "deb https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list
  fi

  apt-get -y update
  apt-get -y install sublime-text
}


main "$@"
