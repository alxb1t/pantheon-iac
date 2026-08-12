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
