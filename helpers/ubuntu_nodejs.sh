#Built on Ubuntu 18.04 Server

#Add required repos to /etc/apt/sources.list
tee -a /etc/apt/sources.list <<'EOL'
deb http://archive.ubuntu.com/ubuntu bionic universe
EOL

#Install required packages
apt-get update
apt-get upgrade
apt-get install -y samba mysql-server nodejs npm

#Configure web root
mkdir /var/www
chown $USER /var/www

#Configure SAMBA
#Need to fix the create/directory modes as currently, they are too open.
tee -a /etc/samba/smb.conf <<'EOL'
[www]
   path = /var/www
   writable = yes
   guest ok = no
   guest only = no
   read only = no
   create mode = 0777
   directory mode = 0777
EOL

service smbd restart

smbpasswd -a $USER
smbpasswd -e $USER

#Configure mySQL
mysql_secure_installation
#Remove bind-address from sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
#Setup users

service mysql restart

#Configure nodeJS
npm install -g nodemon


