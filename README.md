# Ubuntu Server Deployment and Automated Hardening

Automated deployment and hardening of a dual-homed Ubuntu Server VM using Terraform and Ansible.

## Overview

This project provisions an Ubuntu 24.04 VM on Proxmox with two network interfaces:

- **External interface** — internet-facing. SSH and the web server listen exclusively on this interface.
- **Internal interface** (VLAN 150) — isolated internal network. Exposes port 9000 TCP to the device at `10.200.16.100/29`, No management traffic traverses this interface.

Terraform handles VM provisioning. Ansible handles all in-OS configuration and hardening.

## Architecture

```
Internet / Operator access
          │
       [eth0] ← SSH (external only), Nginx port 80 (external only) / IP Assigned via DHCP
          │
   [ Ubuntu VM — ]
          │
       [ens19, 10.200.16.101/29 - VLAN 150] ← port 9000/TCP only
          │
   10.200.16.100 (internal device on VLAN 150)
```

Port 9000 on the internal interface is reserved for internal service traffic

## Repository Structure

```
.
├── terraform/
│   ├── main.tf           # VM and image resources
│   ├── variables.tf      # All environment-specific variables
│   ├── outputs.tf        # VM IP output
│   ├── provider.tf       # Proxmox provider configuration
└── ansible/
    ├── playbook.yml      # Main playbook
    ├── inventory.ini     # Host inventory (update IP after terraform apply)
    ├── group_vars/
    │   └── terraform_vm.yml  # Interface names and internal IP config
    └── roles/
        ├── base/         # System updates, qemu-guest-agent, internal interface config
        ├── ssh/          # SSH hardening, bind to external interface only
        ├── webserver/    # Nginx install, bind to external interface only
        └── hardening/    # UFW rules, sysctl, fail2ban, reboot if required
```

## Requirements

- Terraform >= 1.0 with network access to the Proxmox API (port 8006)
- Proxmox API token with sufficient privileges
- Ansible >= 2.14 on any host with SSH access to the provisioned VM

## Usage

### 1. Configure Terraform variables

In the `terraform/` directory, create `terraform.tfvars`:

```hcl
proxmox_api_token    = "root@pam!terraform=<your-token-secret>"
proxmox_ssh_password = "<your-proxmox-root-password>"
proxmox_endpoint     = "https://<your-proxmox-ip>:8006/"
ssh_public_key       = "ssh-ed25519 <your-public-key>"

# Override bridge names to match your environment if needed
external_bridge = "vmbr0"
internal_bridge = "vmbr1"
```


### 2. Generate an SSH key pair

If you don't already have one, generate a key pair on the machine you will use to access the VM:

The corresponding private key must also be present on your Ansible control node so the playbook can connect to the VM.

### 3. Provision the VM

```bash
cd terraform
terraform init
terraform apply
```

Terraform will download the Ubuntu 24.04 cloud image, provision the VM with two NICs, and inject your SSH key via cloud-init. It will then wait for the qemu-guest-agent to respond.

> **Important:** Terraform will hang after VM creation while waiting for the qemu-guest-agent. This is expected — proceed immediately to step 4 in a second terminal. Once Ansible installs the agent, Terraform will unblock and print the VM IP.

### 4. Update the Ansible inventory

While Terraform is waiting, find the VM's IP from your DHCP server or Proxmox UI and update `ansible/inventory.ini`:

```ini
[terraform_vm]
terraform-vm ansible_host=<vm-ip> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

### 5. Run the Ansible playbook

From your Ansible control node:

```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

### 6. Verify

```bash
terraform output vm_ip
curl http://<vm-ip>
ssh ubuntu@<vm-ip>
```

On the VM, confirm firewall rules:

```bash
sudo ufw status verbose
```

## Variables Reference

### Terraform

| Variable | Description | Default |
|---|---|---|
| `proxmox_endpoint` | Proxmox API URL | `https://YOUR-PROXMOX-IP:8006/` |
| `proxmox_api_token` | API token (required) | — |
| `proxmox_ssh_password` | Proxmox root SSH password (required) | — |
| `proxmox_node` | Proxmox node name | `proxmox` |
| `external_bridge` | Bridge for external NIC | `vmbr0` |
| `internal_bridge` | Bridge for internal NIC | `vmbr1` |
| `vm_name` | VM display name | `terraform-vm` |
| `vm_user` | Cloud-init admin user | `ubuntu` |
| `ssh_public_key` | SSH public key for VM access (required) | — |

### Ansible (group_vars/terraform_vm.yml)

| Variable | Description | Default |
|---|---|---|
| `external_interface` | Auto-detected from default route | `ansible_default_ipv4.interface` |
| `internal_interface` | Auto-detected as remaining interface | derived |
| `internal_ip` | Static IP for the internal interface | `10.200.16.101` |
| `internal_prefix` | Subnet prefix for internal interface | `29` |

## Hardening Applied

**SSH** — bound to external interface only, root login disabled, password authentication disabled, max 3 auth attempts, TCP forwarding disabled.

**Nginx** — bound to external interface only, server version header disabled.

**UFW** — default deny inbound, port 22 and 80 allowed on external interface only, port 9000 allowed on internal interface only.

**Kernel (sysctl)** — IP forwarding disabled, ICMP redirects disabled, source routing disabled, SYN cookies enabled, reverse path filtering enabled, dmesg restricted, SysRq disabled.

**fail2ban** — SSH jail enabled, 3 failed attempts within 10 minutes triggers a 1 hour ban.

## Assumptions and Limitations

The task description references vswitches, which I assume is referring to either Proxmox or VMware. Since I have Proxmox available locally I used the `bpg/proxmox` Terraform provider. If your environment runs VMware vSphere or another hypervisor, the provider block and VM resource in `terraform/main.tf` would need to be adapted.

The VM's external IP is assigned via DHCP, which keeps the Terraform code portable but requires updating the Ansible inventory after each fresh provisioning.

## Design Decisions

**DHCP on the external interface** — portable across environments without requiring knowledge of the target IP range.

**Bridge names as Terraform variables** — `external_bridge` and `internal_bridge` are configurable to accommodate different environments.

**Interface auto-detection in Ansible** — the playbook detects the external interface via the default route and derives the internal interface from what remains, avoiding hardcoded interface names.

**Static IP on internal interface** — the internal interface is assigned `10.200.16.101/29` via netplan to establish L3 connectivity with `10.200.16.100/29`. Configurable via `group_vars`.

**Port 9000** — exposed exclusively on the internal interface. In your production environment I assume this port is used by the Ethereum beacon node or some internal log collection port (prometheus/grafana).

## Future Improvements

Preinstall qemu-guest-agent into the template/image.

Dynamic Ansible inventory that automatically gets IP information from Terraform output
