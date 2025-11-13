#! /bin/bash

VMID=8201
STORAGE=ssd1

cd /var/lib/vz/template/iso
set -x
rm -f jammy-server-cloudimg-amd64.img
wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
qemu-img resize jammy-server-cloudimg-amd64.img 8G
 qm destroy $VMID
 qm create $VMID --name "ubuntu-22.04.LTS-template" --ostype l26 \
    --memory 2048 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 2 \
    --net0 virtio,bridge=vmbr0
 qm importdisk $VMID jammy-server-cloudimg-amd64.img $STORAGE
 qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
 qm set $VMID --boot order=virtio0
 qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF | sudo tee /var/lib/vz/snippets/ubuntu.yaml
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

sudo qm set $VMID --cicustom "vendor=local:snippets/ubuntu.yaml"
sudo qm set $VMID --tags ubuntu-template,jammy,cloudinit,22.04
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm template $VMID
