#!/bin/bash
#Helper script for setting up networking with nmcli
#Should be run as root and is normally called from a higher level script

#Constants
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

#Checked 6 Apr 19
function main() {
  #Check that the script is being run as SUDO.
  if [ "root" = $USER ]; then
    #Running as sudo, as expected
    
    while [[ true ]];
    do
      clear
      echo '1. Create bridge'
      echo '2. Configure interface'
      echo '3. Configure NAT'
      echo '4. Configure IP forwarding'
      echo '5. Install OpenVPN Server'
      echo '6. Install OpenVPN Client'
      echo '7. Install NFS Server'
      echo '8. Install SMB Server'
      echo '9. Add NFS Mount'
      echo '10. Add CIFS Mount'
      echo '11. Install NetworkManager'
      echo '12. Change NetworkManager-wait-online.service timeout'
      echo '13. Save firewall rules (TBA)'
      echo 'Q. Exit'

      read -p "Selection: " choice

      case $choice in
        '1') create_bridge;;
        '2') conf_interface;;
        '3') conf_nat;;
        '4') conf_ipForwarding;;
        '5') install_openvpn_server;;
        '6') install_openvpn_client;;
        '7') install_nfs_server;;
        '8') install_smb_server;;
        '9') add_mount_nfs;;
        '10') add_mount_cifs;;
        '11') install_NetworkManager;;
        '12') changeNMTimeout;;
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





function create_bridge() {
  #Check that NetworkManager is available
  checkNetworkManager

  read -p 'Interface name (br-X): ' ifaceName
  nmcli conn add ifname $ifaceName type bridge con-name $ifaceName
  case $? in 
    0) echo -e "[ ${GREEN}SUCCESS${NC} ] Bridge $ifaceName was created"
      read -n 1 -p 'Does the host require any interfaces to be configured (y/n)? ' continue
      if [[ $continue =~ [yY] ]]; then
        read -p 'Interface IP (10.0.5.X/24): ' ifaceAddress
        read -p 'Interface Gateway (10.0.5.1): ' ifaceGateway
  
        nmcli conn modify id $ifaceName +ipv4.method manual +ipv4.addresses $ifAddress

        if [[ $ifaceGateway == '' ]]; then
          nmcli conn modify id $ifaceName +ipv4.gateway $ifaceGateway
        fi

        case $? in 
          0) echo -e "[ ${GREEN}SUCCESS${NC} ] IP addresses were added to $ifaceName";;
          *) echo -e "[ ${RED}FAILURE${NC} ] The IP addresses could not be added to $ifaceName";;
        esac
      fi
  ;;
    *) echo -e "[ ${RED}FAILURE${NC} ] The bridge interface could not be created";;
  esac
  nmcli conn up id $ifaceName
}

function conf_interface() {
  #Needs work, expects device and connection name to be the same. Perhaps this can delete all 'Wired Connection X' connections and recreate them?

  #Check that NetworkManager is available
  checkNetworkManager

  select ifaceName in $(nmcli -t device | awk -F: '{print $1}');
  do
    #Check that a connection with the same name exists

      #Connection does not already exist
      #nmcli connection add con-name $ifaceName ifname $ifaceName type ethernet

    echo 'Updating' $ifaceName
    read -p 'IP Address (10.0.5.x/24): ' ifaceAddress
    nmcli conn modify id $ifaceName +ipv4.address $ifaceAddress +ipv4.method manual
    case $? in 
      0) echo -e "[ ${GREEN}SUCCESS${NC} ] IP addresses were added to $ifaceName";;
      *) echo -e "[ ${RED}FAILURE${NC} ] The IP addresses could not be added to $ifaceName";;
    esac

    nmcli connection up $ifaceName
  done

}

#Temporarily configures NAT between two interfaces
#Checked 6 Apr 19
function conf_nat() {
  #Check that NetworkManager is available
  checkNetworkManager

  #Ensure that routing is enabled in the kernel (temporary)
  echo 1 > /proc/sys/net/ipv4/ip_forward

  #
  echo 'Select outside interface'
  select ifaceOut in $(nmcli -t device | awk -F: '{print $1}');
  do
    echo 'Select internal inteface'
    select ifaceIn in $(nmcli -t device | awk -F: '{print $1}');
    do
      #From https://www.revsys.com/writings/quicktips/nat.html
      iptables -t nat -A POSTROUTING -o $ifaceOut -j MASQUERADE
      iptables -A FORWARD -i $ifaceOut -o $ifaceIn -m state --state RELATED,ESTABLISHED -j ACCEPT
      iptables -A FORWARD -i $ifaceIn -o $ifaceOut -j ACCEPT
      break
    done
    break
  done

  echo -e "[ ${GREEN}SUCCESS${NC} ] NAT configured"
}

#Allows the kernel to undertake routing of IP traffic on a permanent basis
#Checked 6 Apr 19
function conf_ipForwarding() {
  sed 's/^#*net\.ipv4\.ip_forward=./net.ipv4.ip_forward=1/' /etc/sysctl.conf
  sysctl -p /etc/sysctl.conf

  case $? in 
    0) echo -e "[ ${GREEN}SUCCESS${NC} ] net.ipv4.ip_forward was updated";;
    *) echo -e "[ ${RED}FAILURE${NC} ] There was an error updating net.ipv4.ip_forward";;
  esac
}

function install_openvpn_server() {

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

function install_openvpn_client() {
#  apt install network-manager-openvpn-gnome openvpn-systemd-resolved
  echo "needs work"
  #Not clear if this is required
  #apt install openvpn
}

#Setup an NFS server. Prefered to use if clients will only be linux machines
function install_nfs_server() {

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

  echo "[ ${YELLOW}NOTE${NC} ] Firewall configurationn may be required for some systems."
}


#Setup a SAMBA server. Useful if you need to host files for windows clients
function install_smb_server() {

  apt-get -y install samba

  #Firewall rules
  #Need to allow UDP137,UDP138,TCP139,TCP445.
  #ufw allow 'Samba'

  read -n 1 -p "Do you wish to add an SMB user? (y/n) " continue
  if [[ $continue =~ [yY] ]]; then
    read -p "Username: " username

    useradd -M -N -s /usr/sbin/nologin useru
    
    smbpasswd -a $username
    smbpasswd -e $username
    #SMB users can be found by 
  fi

  read -n 1 -p "Do you wish to add any SMB shares? (y/n) " continue
  if [[ $continue =~ [yY] ]]; then
    read -p "Path of new share: " sharePath

    mkdir $sharePath
    chmod 777 $sharePath

    echo "[public]" >> /etc/samba/smb.conf
    echo "  path = $sharePath" >> /etc/samba/smb.conf
    echo "  browsable = yes" >> /etc/samba/smb.conf
    echo "  create mask = 0660" >> /etc/samba/smb.conf
    echo "  directory mask = 0771" >> /etc/samba/smb.conf
    echo "  writable = yes" >> /etc/samba/smb.conf
    echo "  guest ok = yes" >> /etc/samba/smb.conf
    #echo "#  valid users = " >> /etc/samba/smb.conf
    
    

  fi

  


  systemctl restart nmbd

}

function add_mount_nfs() {
  
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

#
function add_mount_cifs() {
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

#Installs NetowrkManager and configures netplan to use NetworkManager exclusively
#Checked 6 Apr 19 - Need to test once more on fresh install
function install_NetworkManager() {

  apt-get -y install network-manager

  ###Disable netplan
  #Remove existing netplan configs
  rm -rf /etc/netplan/*.yaml

  systemctl start NetworkManager

  #Create a new netplan config file, directing NetworkManager to controll system network interfaces
  touch /etc/netplan/01-network-manager-all.yaml
  echo "network:" >> /etc/netplan/01-network-manager-all.yaml
  echo "  version: 2" >> /etc/netplan/01-network-manager-all.yaml
  echo "  renderer: NetworkManager" >> /etc/netplan/01-network-manager-all.yaml
  
  #Restart netplan
  netplan generate
  if [ $? = 0 ]; then
    netplan apply 
  else
    echo -e "[ ${RED}FAILURE${NC} ] Error occurred whilst applying the new netplan configuration"
  fi

}

#Checks if NetworkManager is available. Used by those functions
# which use nmcli. Reports an error and exits the script if NetworkManager
# installation is cancelled.
#Checked 6 Apr 19
function checkNetworkManager() {
  #Checks that this system has NetworkManager available
  which nmcli > /dev/null
  if [ $? -eq 0 ]; then
    echo -e "[ ${GREEN}SUCCESS${NC} ] NetworkManager is available"
    return 0
  else
    echo -e "[ ${RED}FAILURE${NC} ] NetworkManager not available"
    read -n1 -p "Would you like to install NetworkManager? (y/n) " continue
    if [[ $continue =~ [yY] ]]; then
      install_NetworkManager
    else
      echo -e "\n[ ${RED}FAILURE${NC} ] NetworkManager not available and is required"
      exit 1
    fi
  fi
}

function changeNMTimeout(){
  #Check that NetworkManager is available
  checkNetworkManager

  which nano
  if [[ $? -eq 0 ]]; then
    #Nano exists
    nano /lib/systemd/system/NetworkManager-wait-online.service
  else
    vi /lib/systemd/system/NetworkManager-wait-online.service
  fi
}

function setHostname(){
  echo "Set hostname"
  read -p "New hostname: " name
  hostnamectl set-hostname $name

}

main $@