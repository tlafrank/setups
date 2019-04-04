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
    echo 'Script is running as SUDO, as expected.'

    PS3="Choice: "

    select opt in \
      'Create VM from ISO'\
      'Clone VM'\
      'Configure CIFS'\
      'Exit'
    do
      case $opt in
        'Create VM from ISO') new_vm;;
        'Clone VM') virt-clone;;
        'Configure CIFS') cifs;;
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





function virtstuff {

  read -p 'What is the original VM to clone: ' originalDomain
  read -p 'What is the new VM name: ' newDomain

  virt-clone --original $originalDomain --name $newDomain --auto-clone
}


main $@