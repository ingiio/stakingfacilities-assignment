output "vm_ip" {
  description = "External IP of the VM"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses
}