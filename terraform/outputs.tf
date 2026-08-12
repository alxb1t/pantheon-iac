# outputs.tf — surface the data-source result so plan/apply prints real values.

output "proxmox_nodes" {
  description = "Node names reported by Proxmox (proves the API token works)."
  value       = data.proxmox_virtual_environment_nodes.available.names
}

output "gitadel_vm_id" {
  description = "VMID of the Gitadel VM."
  value       = proxmox_virtual_environment_vm.gitadel.vm_id
}

output "gitadel_ipv4" {
  description = "Static IPv4 assigned to the Gitadel VM via cloud-init."
  value       = var.vm_ip
}
