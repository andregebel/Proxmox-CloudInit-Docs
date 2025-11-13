#! /bin/bash

VMID=8501
STORAGE=ssd1

apt update -y && apt install libguestfs-tools -y
apt install unar -y
cd /var/lib/vz/template/iso
set -x
rm -f kali-linux-2025.3-qemu-amd64.qcow2
wget -q https://eu.mirror.ionos.com/linux/distributions/kali/kali-images/current/kali-linux-2025.3-qemu-amd64.7z
unar kali-linux-2025.3-qemu-amd64.7z
qemu-img resize kali-linux-2025.3-qemu-amd64.qcow2 32G
 qm destroy $VMID
 qm create $VMID --name "kali-linux-2025.3-template" --ostype l26 \
    --memory 4092 --balloon 0 \
    --agent 1 \
    --cpu x86-64-v2-AES --cores 2 --numa 1 \
    --net0 virtio,bridge=vmbr0,mtu=1
 qm importdisk $VMID kali-linux-2025.3-qemu-amd64.qcow2 $STORAGE
 qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
 qm set $VMID --boot order=virtio0
 qm set $VMID --tags kali-template,kali-2025.3,
 qm set $VMID --sshkeys ~/.ssh/authorized_keys
 qm set $VMID --ipconfig0 ip=dhcp
 qm template $VMID
