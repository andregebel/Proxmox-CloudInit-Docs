#! /bin/bash

VMID=8001
STORAGE=ssd1

apt update -y && apt install libguestfs-tools -y
cd /var/lib/vz/template/iso
set -x
rm -f debian-12-generic-amd64+docker.qcow2
wget -q https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 -O debian-12-generic-amd64+docker.qcow2
qemu-img resize debian-12-generic-amd64+docker.qcow2 8G
 qm destroy $VMID
 qm create $VMID --name "debian-12-template-docker" --ostype l26 \
    --memory 2048 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu x86-64-v2-AES --cores 2 --numa 1 \
    --net0 virtio,bridge=vmbr0,mtu=1 \
    --serial0 socket
 qm importdisk $VMID debian-12-generic-amd64+docker.qcow2 $STORAGE
 qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
 qm set $VMID --boot order=virtio0
 qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF | tee /var/lib/vz/snippets/debian-12-docker.yaml
#cloud-config
package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - gnupg
  - ca-certificates
  - curl

runcmd:
  # Ensure guest agent is enabled
  - systemctl enable --now qemu-guest-agent

  # Keyring directory
  - install -m 0755 -d /etc/apt/keyrings

  # Docker GPG key
  - curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc

  # Add Docker repository
  - |
    tee /etc/apt/sources.list.d/docker.sources <<EOF
    Types: deb
    URIs: https://download.docker.com/linux/debian
    Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
    Components: stable
    Signed-By: /etc/apt/keyrings/docker.asc
    EOF

  # Update and install Docker
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Enable Docker service
  - systemctl enable --now docker

  # Reboot after install
  - reboot

# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

qm set $VMID --cicustom "vendor=local:snippets/debian-12-docker.yaml"
qm set $VMID --tags debian-template,debian-12,cloudinit,docker
qm set $VMID --ciuser $USER
qm set $VMID --sshkeys ~/.ssh/authorized_keys
qm set $VMID --ipconfig0 ip=dhcp
qm template $VMID
