#!/bin/bash

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

