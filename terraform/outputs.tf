output "vm_ipv4_addresses" {
  description = "IPv4 addresses reported by the guest agent"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses
}