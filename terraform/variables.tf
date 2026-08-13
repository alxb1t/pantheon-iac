# variables.tf — declares the inputs. Names + types only; real values live in terraform.tfvars (gitignored).

variable "proxmox_endpoint" {
  description = "Proxmox API URL, incl. scheme and port, e.g. https://<HOST_IP>:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token: USER@REALM!TOKENID=SECRET"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (host uses a self-signed cert)"
  type        = bool
  default     = true
}

variable "pve_node" {
  description = "Proxmox node to create the VM on (host-specific)."
  type        = string
}

variable "template_id" {
  description = "VMID of the Alpine cloud-init template to clone."
  type        = number
  default     = 9000
}

variable "vm_id" {
  description = "VMID for the Gitadel VM."
  type        = number
  default     = 100
}

variable "vm_name" {
  description = "Name + cloud-init hostname for the Gitadel VM."
  type        = string
  default     = "gitadel"
}

variable "vm_user" {
  description = "cloud-init username created on the VM."
  type        = string
  default     = "alxb1t"
}

variable "vm_datastore" {
  description = "Datastore for the VM disk + cloud-init drive."
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Network bridge for the VM NIC."
  type        = string
  default     = "vmbr0"
}

variable "vm_disk_size" {
  description = "VM disk size in GB (grown from the template's small base disk)."
  type        = number
  default     = 4
}

variable "vm_memory" {
  description = "Max memory in MB (balloon ceiling)."
  type        = number
  default     = 1024
}

variable "vm_memory_min" {
  description = "Min memory in MB (balloon floor; less than vm_memory enables ballooning)."
  type        = number
  default     = 512
}

variable "vm_ip" {
  description = "Static IPv4 for the VM, outside the DHCP pool (host-specific)."
  type        = string
}

variable "vm_gateway" {
  description = "LAN gateway IPv4 (host-specific)."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the public key injected via cloud-init."
  type        = string
  default     = "~/.ssh/pantheon_ed25519.pub"
}

variable "vendor_data_file_id" {
  description = "Proxmox snippet volume ID for cloud-init vendor-data (guest agent + unlock)."
  type        = string
  default     = "local:snippets/vendor-data.yml"
}

variable "vm_dns_servers" {
  description = "DNS servers for the VM's cloud-init network config."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}
