#! /bin/bash

VMID=8203
STORAGE=ssd1

apt update -y && apt install libguestfs-tools -y
cd /var/lib/vz/template/iso
set -x
rm -f noble-server-cloudimg-amd64.img
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qemu-img resize noble-server-cloudimg-amd64.img 40G
 qm destroy $VMID
 qm create $VMID --name "ubuntu-24.04.LTS+Docker-template" --ostype l26 \
    --memory 8192 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 2 \
    --net0 virtio,bridge=vmbr0
 qm importdisk $VMID noble-server-cloudimg-amd64.img $STORAGE
 qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
 qm set $VMID --boot order=virtio0
 qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF | tee /var/lib/vz/snippets/ubuntu+docker.yaml
#cloud-config
package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - apt-transport-https
  - ca-certificates
  - curl
  - software-properties-common

runcmd:
  # QEMU Guest Agent aktivieren
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent

  # Docker Repository hinzufügen
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update

  # Docker Engine installieren
  - apt-get install -y docker-ce docker-ce-cli containerd.io

  # Docker aktivieren
  - systemctl enable docker
  - systemctl start docker

  # Docker Compose installieren
  - curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  - chmod +x /usr/local/bin/docker-compose

  # Benutzer 'ubuntu' zur Docker-Gruppe hinzufügen (kein sudo nötig)
  #- usermod -aG docker ubuntu
EOF

sudo qm set $VMID --cicustom "vendor=local:snippets/ubuntu+docker.yaml"
sudo qm set $VMID --tags ubuntu-template,noble,cloudinit,24.04,docker
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm template $VMID
