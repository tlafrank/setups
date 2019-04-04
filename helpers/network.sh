#!/bin/bash
#Helper script for setting up networking with nmcli
#Should be run as root and is normally called from a higher level script

#Check that this system has nmcli

#Check that the script is being run as SUDO.

function main() {
  if [ "root" = $USER ]; then
    clear

    which nmcli > /dev/null

    if [ $? -eq 0 ]; then

      PS3="Choice: "
      select opt in \
        'Create bridge'\
        'Configure interface'\
        'Configure NAT'\
        'Configure IP forwarding'\
        'Install OpenVPN Server'\
        'Install OpenVPN Client'\
        'Install NFS Server'\
        'Add NFS Mount'\
        'Add CIFS Mount'\
        'Install NetworkManager'\
        'Exit'
      do
        case $opt in
          'Create bridge') create_bridge;;
          'Configure interface') conf_interface;;
          'TBA') networkTBA;;
          'Configure NAT') conf_nat;;
          'Configure IP forwarding') conf_ipForwarding;;
          'Install OpenVPN Server') install_openvpn_server;;
          'Install OpenVPN Client') install_openvpn_client;;
          'Install NFS Server') install_nfs_server;;
          'Add NFS Mount') add_mount_nfs;;
          'Add CIFS Mount') add_mount_cifs;;

          'Install NetworkManager') install_NetworkManager;;
          *)
            exit;
            break;
         ;;
        esac
      done

    else
      #Could ask to install NetworkManager
      echo 'NetworkManager is not available on this system'
      echo 'No changes have been made'      
    fi
  fi

}







function create_bridge() {
  #Need to set ipv4.method to link-local
  #nmcli conn modify br-40 ipv6.method ignore ipv4.method link-local
  #Restart NM?
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

function conf_nat() {
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


}

function conf_ipForwarding() {
  sysctl -w net.ipv4.ip_forward=1 > /dev/null
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
  apt install network-manager-openvpn-gnome openvpn-systemd-resolved

  #Not clear if this is required
  #apt install openvpn
}

#
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

  echo "[   NOTE  ] Firewall configurationn may be required for some systems."
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


function install_NetworkManager() {

  apt-get -y install network-manager

  ###Disable netplan
  #Delete existing netplan configs
  temp=$(mktemp /tmp/netplanXXXX.yaml)
  mv /etc/netplan/01-network-manager-all.yaml $temp
  echo "Original netplan config moved to "$temp


  #Create a new netplan config file, directing NetworkManager to controll system network interfaces
  touch /etc/netplan/01-network-manager-all.yaml
  echo "network:" >> /etc/netplan/01-network-manager-all.yaml
  echo "  version: 2" >> /etc/netplan/01-network-manager-all.yaml

  #Restart netplan
  netplan generate
  if [ $? = 0 ]; then
    netplan apply 2> /dev/null
    netplan apply 2> /dev/null #Every second execution throws an error for some reason.
  else
    echo "An error occurred whilst generating the netplan config file."
  fi

  #Fix routes
  #ip route del default

}





main $@