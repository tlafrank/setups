#!/bin/bash
#Helper script for setting up networking with nmcli
#Should be run as root and is normally called from a higher level script

#Check that this system has nmcli

#Check that the script is being run as SUDO.
if [ "root" = $USER ]; then
  clear

  which nmcli > /dev/null

  if [ $? -eq 0 ]; then

    PS3="Choice: "
    select opt in \
      'Create bridge'\
      'Configure interface'\
      'Configure NAT'\
      'Configure IP forwarding'
    do
      case $opt in
        'Create bridge')
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
        ;;
        'Configure interface')
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

  else
    #Could ask to install NetworkManager
    echo 'NetworkManager is not available on this system'
    echo 'No changes have been made'

    
  fi
fi



  