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
      'Update/Upgrade'\
      'Install Git'\
      'Install Docker'\
      'Remove SUDO Password Requirement'\
      'Setup networking'\
      'Exit'
    do
      case $opt in
        'Update/Upgrade') update;;
        'Install Git') install_git;;
        'Install Docker') install_docker;;
        'Remove SUDO Password Requirement') removeSudoPassword;;
        'Setup networking') setup_network;;
        *)
          exit;
          break;
        ;;
      esac
      echo 'Update/Upgrade'
      echo 'Install Git'
      echo 'Install Docker'
      echo 'Remove SUDO Password Requirement'
      echo 'Setup networking'
      echo 'Exit'
    done
  else
    echo 'Script is not running as SUDO (required). Exiting with no changes.'
  fi
}

#Update and upgrade the system
#Checked 4 Apr 19
function update {
  apt-get -y update
  apt-get -y upgrade
}

#Install and conduct basic configuration of git
function install_git() {
  apt-get -y install git

  read -p "Email to use for git registration: " email
  git config --global user.email $email

  read -p "Name to use for git registration: " name
  git config --global user.name $name
}


function install_docker {
  #Installs docker
  apt-get -y install apt-transport-https ca-certificates gnupg-agent software-properties-common
  
  #Add the GPG key
  wget -qO - https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  
  apt-get -y update
  
  apt-get install docker-ce docker-ce-cli containerd.io

  #Add current user to docker group
  read -n 1 -p "Add the current user $USER to the docker group? (y/n)?" continue
  if [[ $continue =~ [yY] ]]; then
    echo "adding user"
  fi

}

function removeSudoPassword {
  echo 'made it here'
}

function setup_network() {
  $DIR/helpers/network.sh
}

main "$@"
