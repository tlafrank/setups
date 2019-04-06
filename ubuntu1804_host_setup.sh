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
    #Running as sudo, as expected
    
    while [[ true ]];
    do
      clear
      echo '1. Install KVM'
      echo '2. Add desktop icon'
      echo '3. Install Sublime'
      echo 'Q. Exit'

      read -p "Selection: " choice

      case $choice in
        '1') install_kvm;;
        '2') addDesktopIcon;;
        '3') install_sublime;;
        'Q') break;;
        'q') break;;
        *) echo "Invalid Selection";;
      esac
      read -n 1 -p "Press any key to continue..."
    done
  else
    echo 'Script is not running as SUDO (required). Exiting with no changes.'
  fi
}


function install_kvm {
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
