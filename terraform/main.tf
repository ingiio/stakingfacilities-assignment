data "proxmox_virtual_environment_nodes" "available_nodes" {}

output "proxmox_nodes" {
  value = data.proxmox_virtual_environment_nodes.available_nodes.names
}

locals {
  vm_external_ip = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses[1][0]
}

resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node
  file_name    = "ubuntu-24.04-cloudimg-amd64.img"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_file" "cloud_init_qemu_guest_agent" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "cloud-init-qemu-guest-agent.yaml"
    data = <<-EOF
      #cloud-config
      hostname: ${var.vm_name}

      users:
        - default
        - name: ${var.vm_user}
          groups:
            - sudo
          shell: /bin/bash
          sudo: ALL=(ALL) NOPASSWD:ALL
          ssh_authorized_keys:
            - ${var.ssh_public_key}

      package_update: true
      packages:
        - qemu-guest-agent

      runcmd:
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
    EOF
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name      = var.vm_name
  node_name = var.proxmox_node

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    size         = 20
    discard      = "on"
  }

  network_device {
    bridge = var.external_bridge
    model  = "virtio"
  }

  network_device {
    bridge  = var.internal_bridge
    model   = "virtio"
    vlan_id = 150
  }

  operating_system {
    type = "l26"
  }

  initialization {
  ip_config {
    ipv4 {
      address = "dhcp"
    }
  }

  ip_config {
    ipv4 {
      address = "${var.internal_ip}/${var.internal_prefix}"
    }
  }

  user_data_file_id = proxmox_virtual_environment_file.cloud_init_qemu_guest_agent.id
}
}

resource "local_file" "ansible_inventory" {
  content = <<-EOF
    [terraform_vm]
    terraform-vm ansible_host=${local.vm_external_ip} ansible_user=${var.vm_user} ansible_ssh_private_key_file=/root/.ssh/id_ed25519
  EOF

  filename = "${path.module}/../ansible/inventory.ini"
}
