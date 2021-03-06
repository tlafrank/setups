#!/bin/bash
#Used to prepare a Centos 7 VM prior to installing SW


GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

#echo -e "[ ${GREEN}SUCCESS${NC} ] test"
#echo -e "[ ${RED}FAILED${NC} ] test"

function main {
  #Check that the script is being run as SUDO.
  if [ "root" = $USER ]; then
    echo 'Script is running as SUDO, as expected.'

    PS3="Choice: "

    select opt in \
      'Update/Upgrade'\
      'Post Clone Actions'\
      'Bash Completion'\
      'Install Git'\
      'Install Nano'\
      'Configure CIFS'\
      'Add NFS Share'\
      'Setup networking'\
      'Install Oracle Java'\
      'Fix SSH'\
      'Exit'
    do
      case $opt in
        'Update/Upgrade') update;;
        'Post Clone Actions')
          fix_ssh
          #set_interface
          change_hostname
        ;;
        'Bash Completion') bash_completion;;
        'Install Git') git;;
        'Install Nano') nano;;
        'Configure CIFS') cifs;;
        'Install Oracle Java') java;;
        'Fix SSH') fix_ssh;;
        'Setup networking') network;;
        'Add NFS Share') addNFSMount;;
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



function addNFSMount {
  
  yum -y install nfs-utils.x86_64

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


function network {
  ./helpers/network.sh
}

function unzip {
  #Install unzip
  yum -y install unzip

}

function update {
  #Get the latest software
  yum -y update
  if [ $? == 0 ]; then
    echo -e "[ ${GREEN}SUCCESS${NC} ] Update succeeded"
  else
    echo -e "[ ${RED}FAILURE{NC} ] A non-zero error code was thrown when attempting to update the system"
  fi
}

function bash_completion {
  #Configure bash -compeletion
  yum install -y bash-completion
  source /usr/share/bash-completion/bash_completion
}

function git {
  #Install git
  yum install -y git
  #git clone https://github.com/tlafrank/setup_centos7/
}

function fix_ssh {

  #Fix SSH
  #Set useDNS no in /etc/ssh

  #Regenerate SSH keys

  systemctl restart sshd
}

function ntp {
  echo 'NTP'
  #Install NTP
  #yum install -y ntp
  #Configure NTP
}

function nano {  
  #Install nano text editor
  yum install -y nano
}

function java {
  #Install JDK
  #Can't use 'yum install -y java' as this is OpenJDK

#Get user to choose source
  curl -L -b "oraclelicense=a" -O https://download.oracle.com/otn-pub/java/jdk/8u201-b09/42970487e3af4f5aa5bca3f542482c60/jdk-8u201-linux-x64.rpm
  yum localinstall -y jdk-8u201-linux-x64.rpm 

  #Centos jave version selection
  alternatives --config java
  
  #Ubuntu instructions
  #add-apt-repository ppa:webupd8team/java
  #apt update
  #apt install oracle-jave8-installer
  #Select the version of java to use
  #update-alternatives --config java
}

function change_hostname {

  read -p 'New hostname to set: ' newHostname
  nmcli general hostname $newHostname

}



main "$@"