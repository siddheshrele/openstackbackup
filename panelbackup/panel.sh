#!/bin/bash

#####################################################################
# Description:: Backups openstack configuration using incrimental backup 
# Author:: Siddhesh Rele
# Requires:: rsync utility 
# for queries mail at sidluckie@gmail.com
# All rights reserved.
######################################################################


counter=$(date +"%r")
backdir=/OSbackup/`eval date +%Y%m%d`/
filename="$backdir"mysql-`hostname`-`eval date +%Y%m%d`.sql
prio=19


echo "Backup started at $counter"

#Checks for etc dir and creates if dose not exist
if [ ! -d "$backdir"etc"" ]; then
mkdir -p "$backdir"etc
fi

#Checks for log dir and creates if dose not exist
if [ ! -d "$backdir"var/log"" ]; then
mkdir -p "$backdir"var/log
fi


#Checks for lib dir and creates if dose not exist
if [ ! -d "$backdir"var/lib"" ]; then
mkdir -p "$backdir"var/lib
fi

#Checks for lib dir and creates if dose not exist
if [ ! -d "/OSimage/var/lib" ]; then
mkdir -p /OSimage/var/lib
fi

##Function backup config
function backup_config {

for i in keystone glance nova neutron openstack-dashboard httpd ; \
  do nice -n "$prio" rsync -arpvog /etc/$i "$backdir"etc/  ; \
  done


}

##Function backup databases 
function backup_db {

nice -n "$prio" /usr/bin/mysqldump -u root --opt --add-drop-database --all-databases > $filename

}

##Function backup loga
function backup_logs {
for i in glance nova; \
  do nice -n "$prio" rsync -arpvog /var/log/$i "$backdir"var/log ; \
  done

}

##Function backup vm
function backup_vm {
for i in  nova; \
  do nice -n "$prio" rsync -arpvog --exclude=disk --exclude='_base/*'  /var/lib/$i "$backdir"var/lib ; \
  done
}

##Function backup images
function backup_images {
for i in  glance; \
  do nice -n "$prio" rsync -arpvog  /var/lib/$i /OSimage/var/lib ; \
  done
}

#backup keystone_rc

function backup_keyrc  {
for i in keystonerc_admin keystonerc_demo  ; \
  do nice -n "$prio" rsync -arpvog ~/$i "$backdir"; \
  done
}



backup_logs
backup_db
backup_config
backup_images
backup_vm
backup_keyrc
echo "Backup ended  at $counter"
exit
