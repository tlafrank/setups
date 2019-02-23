#!/bin/bash
#Based upon the instructions at https://linuxconfig.org/install-and-set-up-kvm-on-ubuntu-18-04-bionic-beaver-linux
#test

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


function removeSudoPassword {
  echo 'made it here'
}

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

  #Firewall configurationn may be required for some systems

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

function sublime {

  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
  dd-apt-repository 'deb https://download.sublimetext.com/ apt/stable/'
  apt-get -y install sublime-text

}


function network {

  PS3="Choice: "

  clear

  select opt in \
    'Create bridge'\
    'Configure interface'\
    'Configure NAT'\
    'Configure IP forwarding'
  do
    case $opt in
      'Create bridge')
        read -p 'Interface name (br-X): ' ifaceName
        nmcli conn add ifname $ifaceName type bridge con-name $ifaceName
        case $? in 
          0) echo -e "[ ${GREEN}SUCCESS${NC} ] Bridge $ifaceName was created"
            read -p 'Does the host require any interfaces to be configured? ' continue
            if [ continue = 'y' ]; then
              read -p 'Interface IP (10.0.5.X/24): ' ifaceAddress
              read -p 'Interface Gateway (10.0.5.1): ' ifaceGateway
        
              nmcli conn modify id $ifaceName +ipv4.method manual +ipv4.addresses $ifAddress
              case $? in 
                0) echo -e "[ ${GREEN}SUCCESS${NC} ] IP addresses were added to $ifaceName";;
                *) echo -e "[ ${RED}FAILURE${NC} ] The IP addresses could not be added to $ifaceName";;
              esac
            fi
        ;;
          *) echo -e "[ ${RED}FAILURE${NC} ] The bridge interface could not be created";;
        esac

        if [ $ifaceGateway == '' ]; then
          nmcli conn modify id $ifaceName +ipv4.gateway $ifaceGateway
        fi
        nmcli conn up id $ifaceName
      ;;
      'Configure interface')
        select ifaceName in $(nmcli -t device | awk -F: '{print $1}');
        do
          echo 'Updating' $ifaceName
          read -p 'IP Address (10.0.5.x/24): ' ifaceAddress
          nmcli conn modify id $ifaceName +ipv4.address $ifaceAddress +ipv4.method manual
          case $? in 
            0) echo -e "[ ${GREEN}SUCCESS${NC} ] IP addresses were added to $ifaceName";;
            *) echo -e "[ ${RED}FAILURE${NC} ] The IP addresses could not be added to $ifaceName";;
          esac

          nmcli connection up $ifaceName
        done
      ;;
      'TBA') networkTBA;;
      'Configure NAT')
        #Ensure that routing is enabled in the kernel
        echo 1 > /proc/sys/net/ipv4/ip_forward

        #
        echo 'Select outside interface'
        select ifaceOut in $(nmcli -t device | awk -F: '{print $1}');
        do
          echo 'Select internal inteface'
          select ifaceIn in $(nmcli -t device | awk -F: '{print $1}');
          do
            #eth1 = ifaceIn
            #eth0 = ifaceOut
            #From https://www.revsys.com/writings/quicktips/nat.html
            iptables -t nat -A POSTROUTING -o $ifaceOut -j MASQUERADE
            iptables -A FORWARD -i $ifaceOut -o $ifaceIn -m state --state RELATED,ESTABLISHED -j ACCEPT
            iptables -A FORWARD -i $ifaceIn -o $ifaceOut -j ACCEPT

          done
        done
      ;;
      'Configure IP forwarding')
        sysctl -w net.ipv4.ip_forward=1 > /dev/null
        case $? in 
          0) echo -e "[ ${GREEN}SUCCESS${NC} ] net.ipv4.ip_forward was updated";;
          *) echo -e "[ ${RED}FAILURE${NC} ] There was an error updating net.ipv4.ip_forward";;
        esac
      ;;
      *)
        exit;
        break;
     ;;
    esac
  done
}

function github {
  apt -y install git

  read -p "Email to use for git registration: " email
  read -p "Name to use for git registration: " name

  git config --global user.email $email
  git config --global user.name $name
}

function openvpn {
  apt install network-manager-openvpn-gnome openvpn-systemd-resolved

  #Not clear if this is required
  #apt install openvpn
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
  clear
  echo 'Script is running as SUDO, as expected. xx'

  PS3="Choice: "

  select opt in \
    'Update/Upgrade'\
    'Install KVM'\
    'Install Git'\
    'Install OpenVPN Client'\
    'Configure CIFS'\
    'Setup NFS Server'\
    'Setup networking'\
    'Remove SUDO Password Requirement'\
    'Exit'
  do
    case $opt in
      'Update/Upgrade') update;;
      'Install KVM') kvm;;
      'Install Git') git;;
      'Install OpenVPN Client') openvpn;;
      'Configure CIFS') cifs;;
      'Setup networking') network;;
      'Remove SUDO Password Requirement') removeSudoPassword;;
      'Setup NFS Server') setupNFSServer;;
      *)
        exit;
        break;
      ;;
    esac
  done
else
  echo 'Script is not running as SUDO (required). Exiting with no changes.'
fi
