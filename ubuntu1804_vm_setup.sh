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
      echo '1. Create VM from ISO'
      echo '2. Clone VM'
      echo '3. Move VM to another host'
      echo '4. Deploy VM from tar.gz file'
      echo '5. Expand VM volume'
      echo 'Q. Exit'

      read -p "Selection: " choice

      case $choice in
        '1') new_vm;;
        '2') clone_vm;;
        '3') move_vm;;
        '4') deploy_vm;;
        '5') expand_vm_storage;;
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
function clone_vm {

  echo "What VM would you like to clone?"
  echo "VM will be shutdown"
  select originalDomain in $(virsh list --all | awk 'NR>2 {print $2}' | grep -v '^$');
  do
    read -p 'What is the new VM name: ' newDomain

    echo -e "[ ${YELLOW}INFO${NC} ] Shutting down $originalDomain, if up"
    virsh shutdown $originalDomain 2&> /dev/null

    echo -e "[ ${YELLOW}INFO${NC} ] Cloning $originalDomain"
    virt-clone --original $originalDomain --name $newDomain --auto-clone

    if [ $? == 0 ]; then
      echo -e "[ ${GREEN}SUCCESS${NC} ] $newDomain was created"
    else
      echo -e '[ ${RED}FAILURE{NC} ] A non-zero error code was thrown when attempting to clone' $originalDomain
    fi
    break
  done

}

#Moves an existing VM to another host
function move_vm {

  echo "What VM would you move?"
  select originalDomain in $(virsh list --all | awk 'NR>2 {print $2}' | grep -v '^$');
  do
    echo "Moving $originalDomain"
    virsh shutdown $originalDomain 2&> /dev/null

    CUR_DIR=$(pwd)
    
    cd /tmp/

    echo -e "[ ${YELLOW}INFO${NC} ] Dumping VMs XML definition"
    virsh dumpxml $originalDomain > vm_definition.xml

    echo -e "[ ${YELLOW}INFO${NC} ] Moving volume"
    mv $(grep '<source file=' vm_definition.xml | awk -F\' '{print $2}') /tmp/volume.qcow2

    echo -e "[ ${YELLOW}INFO${NC} ] Adding XML and volume to Tarball"
    tar -cf $originalDomain.tar vm_definition.xml volume.qcow2

    echo -e "[ ${YELLOW}INFO${NC} ] Compressing Tarball"
    gzip $originalDomain.tar

    echo -e "[ ${YELLOW}INFO${NC} ] Removing temporary files"
    rm /tmp/vm_definition.xml
    rm /tmp/volume.qcow2

    echo -e "[ ${YELLOW}INFO${NC} ] Removing $originalDomain"
    virsh undefine $originalDomain

    echo -e "[ ${YELLOW}INFO${NC} ] Moving packaged VM to home"
    mv $originalDomain.tar.gz ~

    #virt-clone --original $originalDomain --name $newDomain --auto-clone

    if [ $? == 0 ]; then
      echo -e "[ ${GREEN}SUCCESS${NC} ] $originalDomain was packaged for move to another host"
    else
      echo -e "[ ${RED}FAILURE{NC} ] $originalDOmain was unable to be moved"
    fi
    break
  done

  cd $CUR_DIR
}


#
function deploy_vm() {
  echo "Deploy a VM from a packaged *.tar.gz file"

  echo "Use absolute paths for now (don't use ~)"
  read -e -p "Path to packaged VM: " path

  echo -e "[ ${YELLOW}INFO${NC} ] Extracting $path"
  tar xzf $path -C /tmp/

  echo -e "[ ${YELLOW}INFO${NC} ] Moving volume to libvirt image directory"
  mv /tmp/volume.qcow2 $(grep '<source file=' /tmp/vm_definition.xml | awk -F\' '{print $2}') 

  echo -e "[ ${YELLOW}INFO${NC} ] Importing the VM XML definition"
  virsh define /tmp/vm_definition.xml
  rm /tmp/vm_definition.xml

  echo -e "[ ${GREEN}SUCCESS${NC} ] VM was deployed"

}

function expand_vm_storage() {
  echo "Expand a volume"

  echo "What volume would you ike to expand?"
  echo "VM will be shutdown"
  select volumeFile in $(ls /var/lib/libvirt/images/);
  do
    read -p 'How much to increase volume by (Gb): ' newSize

    echo -e "[ ${YELLOW}INFO${NC} ] Shutting down $originalDomain, if up"
    #virsh shutdown $originalDomain 2&> /dev/null

    qemu-img resize /var/lib/libvirt/images/$volumeFile +$newSize"G"

    if [ $? == 0 ]; then
      echo -e "[ ${GREEN}SUCCESS${NC} ] $newDomain was created"
      echo "Expand the volume within the VM using the X command"
    else
      echo -e '[ ${RED}FAILURE{NC} ] A non-zero error code was thrown when attempting to clone' $originalDomain
    fi
    break
  done



}

main $@