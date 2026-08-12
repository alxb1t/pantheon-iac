# main.tf — a read only data source to prove auth + connectivity

data "proxmox_virtual_environment_nodes" "available" {}
