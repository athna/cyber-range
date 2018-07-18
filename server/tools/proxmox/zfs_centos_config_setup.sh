#!/bin/bash
# TODO UUID変更は本当に必要ないのかの究明
# TODO ファイル分割
# TODO TEMPLATE_NAMEの引数使っていないので削除

if [ $# -ne 4 ]; then
    echo "[vm num] [IP Address] [PC type] [TEMPLATE_NAME] need"
    echo "example:"
    echo "$0 111 192.168.110.11 client"
    exit 1
fi

tool_dir=/root/github/cyber_range/server/tools/proxmox

VM_NUM=$1
IP_ADDRESS=$2
PC_TYPE=$3
TEMPLATE_NAME=$4
VG_NAME="vg_$VM_NUM"

DISK_DATA_DIR="/dev/rpool/data"
DISK_DATA_FILE="$DISK_DATA_DIR/vm-${VM_NUM}-disk-1"
MOUNT_DIR="/mnt/vm$VM_NUM"
NEW_VG_NAME="vg_$VM_NUM"

MAX_PART=16

# ZFS Cloneが終わるのを待つ
while [ ! -e $DISK_DATA_FILE ]; do
    sleep 1
done

# parted install LVM is need parted
result=`dpkg -l | grep parted`
if [ ${#result} -eq 0 ]; then
    apt-get install -y parted
fi
modprobe nbd max_part=16

HANDRED_NUM=${VM_NUM:0:1}
HANDRED_NUM=$((HANDRED_NUM-1))
#TEN_NUM=${VM_NUM:1:1}
ONE_NUM=${VM_NUM:2:1}
ONE_NUM=$((ONE_NUM-1))
NBD_NUM=$(((HANDRED_NUM*6 + ONE_NUM) % MAX_PART))

# 排他制御
#LOCK_FILE="/tmp/nbd${NBD_NUM}.lock"
#lockfile $LOCK_FILE

qemu-nbd -c /dev/nbd$NBD_NUM -f raw $DISK_DATA_FILE # 拡張子を明示する
sleep 2
partprobe /dev/nbd$NBD_NUM
   
# cloneによるPV,VGのUUID副重問題の解決
TEMP_VG_NAME=`vgdisplay | grep 'VG Name' | grep -v 'pve' | awk '{ print $3 }'`
pvchange --uuid /dev/nbd${NBD_NUM}p2
vgrename $TEMP_VG_NAME $NEW_VG_NAME      # kernel panicの原因
vgchange --uuid $NEW_VG_NAME
vgchange -ay $NEW_VG_NAME


mkdir $MOUNT_DIR

# boot config edit grub
#mount $DATA_DIR/vm-${VM_NUM}-disk-1-part1 $MOUNT_DIR 左でもできた
mount /dev/nbd${NBD_NUM}p1 $MOUNT_DIR
sed -i -e "s/$TEMP_VG_NAME/$NEW_VG_NAME/g" $MOUNT_DIR/grub/grub.conf
sync
sync
sync
umount $MOUNT_DIR

# Phisical Volume mount
mount /dev/$VG_NAME/lv_root /mnt/vm$VM_NUM

# boot config edit fstab
# TODO UUID change
#VG_UUID=`vgdisplay vg_$VM_NUM | grep 'VG UUID' | awk '{print $3}'`
#sed -i -e "s/UUID=\w{6}-\w{4}-\w{4}-\w{4}......\t/UUID=$VG_UUID\t/g" /mnt/vm$VM_NUM/etc/fstab
sed -i -e "s/$TEMP_VG_NAME/$NEW_VG_NAME/g" $MOUNT_DIR/etc/fstab

# VM clone setup
$tool_dir/clone.sh $VM_NUM $IP_ADDRESS $PC_TYPE$VM_NUM
$tool_dir/nfs_setup.sh $VM_NUM $IP_ADDRESS $PC_TYPE

# Phisical Volume umount
sync
sync
sync
umount $MOUNT_DIR

# cleanup
rmdir $MOUNT_DIR

vgchange -an $NEW_VG_NAME
qemu-nbd -d /dev/nbd$NBD_NUM

# 排他制御終了
#rm -rf $LOCK_FILE
