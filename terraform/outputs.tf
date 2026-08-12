# outputs.tf — surface the data-source result so plan/apply prints real values.

output "proxmox_nodes" {
  description = "Node names reported by Proxmox (proves the API token works)."
  value       = data.proxmox_virtual_environment_nodes.available.names
}
