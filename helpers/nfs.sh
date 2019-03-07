#!/bin/bash


function main {
  #Check that the script is being run as SUDO.
  if [ "root" = $USER ]; then
    echo 'Script is running as SUDO, as expected.'

    #Configure shares
    echo "Do you wish to add a share?"
    select continue in "Yes" "No"; do
      case $continue in
        Yes )
          #Get details to add the share to fstab
          read -p "What is the address: //" address
          read -p "Where is this to be mounted: " mount
          read -p "What is the username: " username

    echo $mount

          mkdir $mount
          $(mount -t cifs -o username=$username //$address $mount)

          echo "Do you wish to add another share?"
          echo "1) Yes"
          echo "2) No"
      ;;
        No ) break;;
      esac
    done

  else
    echo 'Script is not running as SUDO (required). Exiting with no changes.'
  fi
}


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

main "$@"