variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  default     = "https://10.1.1.10:8006/"
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  default     = "proxmox"
}

variable "external_bridge" {
  description = "Proxmox bridge for external interface"
  default     = "vmbr0"
}

variable "internal_bridge" {
  description = "Proxmox bridge for internal VLAN interface"
  default     = "vmbr1"
}

variable "vm_name" {
  description = "Name of the VM"
  default     = "terraform-vm"
}

variable "vm_user" {
  description = "Default admin user for the VM"
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
}

variable "proxmox_ssh_password" {
  description = "Proxmox root SSH password"
  sensitive   = true
}