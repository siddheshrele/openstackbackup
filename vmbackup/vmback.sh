#!/bin/bash

#####################################################################
# Description:: Backups vm live of openstack using incrimental backup 
# Author:: Siddhesh Rele
# Requires:: rsync and libvirt utility 
# for queries mail at sidluckie@gmail.com
# All rights reserved.
######################################################################

backdir=/OSbackup/`eval date +%Y%m%d`
sspath=/tempsnap/vmimgs
bimg=/var/lib/nova/instances
baseimg=/OSbackup/base
prio=19
log=$backdir/`eval date +%Y%m%d`.log

#creates backup dir and base folder
mkdir -p "$backdir"/instances

#rsync the base images folder

mkdir -p $baseimg

nice -n "$prio" rsync -arpvog $bimg/_base $baseimg

echo Base images updated sucessfully


for vm in $(virsh list --name );
do

#make snapshot dir because we clean snapshot temporary image file after merging the changes

mkdir -p $sspath

#Get Disk list of vm and origanal path of disk

disklist=`virsh domblklist $vm | grep vda | cut -d ' ' -f9`
inid=`echo "$disklist" | cut -d '/' -f6`

#create snapshot
virsh snapshot-create-as $vm snapshot-$vm "snap $vm" \
  --diskspec vda,file=$sspath/snap1-$vm.qcow2 \
  --disk-only --atomic

if [ -f $sspath/snap1-$vm.qcow2 ]; then

#check snapshot is created and get snapshot path
sdisk=`virsh domblklist $vm | grep vda | cut -d ' ' -f9`

#commit block changes only if disk path is changed after snapshot.

if [ "$disklist" != "$sdisk" ]; then

#rsync is made as per instance id
nice -n "$prio" rsync -arpvog $bimg/$inid $backdir/instances

#adds the backing file info
qemu-img info $disklist  | grep "backing file" | cut -d " " -f 3 > "$backdir"/instances/$inid/dinfo

#command automatically revert the file to original file.
virsh blockcommit --domain $vm --path $sspath/snap1-$vm.qcow2  --base  $disklist --pivot --verbose

#checks if changes are committed successfully
if [ $? -eq 0 ]; then

#checks the path after snapshot is reverted
pcheck=`virsh domblklist $vm | grep vda | cut -d ' ' -f9`

if [ "$disklist" == "$pcheck" ]; then

echo "successfully reverted to origainal disk path of $vm"

else

#exits the script to preserves data incase of failure by exiting the script and saving the snapshot

echo "cannot successfully revert to origainal disk path of $vm"
exit 1 
fi

#Removes snapshot and deletes snapshot file
virsh snapshot-delete $vm snapshot-$vm --metadata

if [ $? -eq 0 ]; then

echo "snaphot delete successfully for $vm"

else

echo "snaphot cannot be delete successfully for $vm"

fi

#clean temporary image files after commit is completed

rm -rf $sspath

if [ -f $backdir/instances/$inid/disk ]; then

echo "backup completed sucessfully for $vm"

fi

fi

#After failing sanpshot changes starts here
else

echo "snapshot path is not created hence changes cannot be commited for $vm"

fi

else

echo "snapshot cannot be created for  $vm"

fi

done

exit 0

