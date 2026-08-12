# gitadel-vm.tf — the Gitadel VM: a declarative clone of the Alpine template.
# Replaces the hand-run `qm clone/set/start` with code Terraform owns and can destroy.

resource "proxmox_virtual_environment_vm" "gitadel" {
  name      = var.vm_name
  node_name = var.pve_node
  vm_id     = var.vm_id

  # Clone the Phase-2 template instead of building from scratch.
  clone {
    vm_id = var.template_id
    full  = true
  }

  # Proxmox talks to the guest via the agent the template installed.
  agent {
    enabled = true
    timeout = "5m"
  }

  cpu {
    cores = 1
    type  = "host"
  }

  # Ballooning: dedicated = ceiling, floating = floor. floating < dedicated turns it ON,
  # so the VM hands idle RAM back to the 8 GB host (Gitadel's RAM budget).
  memory {
    dedicated = var.vm_memory
    floating  = var.vm_memory_min
  }

  # Grow the cloned disk from the template's tiny 200 MB base to a usable size.
  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.vm_disk_size
  }

  # cloud-init: per-VM identity (Proxmox generates user-data from these).
  initialization {
    datastore_id = var.vm_datastore

    dns {
      servers = var.vm_dns_servers
    }

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/24"
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
    }

    # Keep the template's vendor-data (guest agent + account unlock). Without this line
    # bpg regenerates cloud-init WITHOUT vendor-data — and key-login would break again.
    vendor_data_file_id = var.vendor_data_file_id
  }

  network_device {
    bridge = var.vm_bridge
  }

  # Alpine needs a serial console (matches the template).
  serial_device {}

  vga {
    type = "serial0"
  }
}
