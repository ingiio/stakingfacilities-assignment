data "proxmox_virtual_environment_nodes" "available_nodes" {}

output "proxmox_nodes" {
  value = data.proxmox_virtual_environment_nodes.available_nodes.names
}

resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node
  file_name    = "ubuntu-24.04-cloudimg-amd64.img"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
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

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }
}