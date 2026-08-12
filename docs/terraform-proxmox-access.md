# Terraform → Proxmox access (least-privilege API token)

How to grant Terraform access to Proxmox VE with a **dedicated, least-privilege** API
token instead of `root`. Run once on the Proxmox host (as root / via `sudo`). No secrets
live in this document — the token's secret value is shown once at creation and kept out
of git (see "Wiring into Terraform").

## Why not root

The token sits on the workstation in a gitignored `terraform.tfvars`. If it leaks it
should be able to manage VMs — not own the hypervisor. So we create a custom role with
only the privileges Terraform exercises, a dedicated API-only user in Proxmox's own `pve`
realm, and a token on that user.

## 1. Create the least-privilege role

```bash
sudo pveum role add TerraformProv -privs "VM.Allocate VM.Clone VM.Config.CPU VM.Config.Memory VM.Config.Disk VM.Config.CDROM VM.Config.Network VM.Config.HWType VM.Config.Options VM.Config.Cloudinit VM.PowerMgmt VM.Audit VM.GuestAgent.Audit Datastore.AllocateSpace Datastore.Audit SDN.Use Sys.Audit"
```

What each privilege is for:

| Privilege(s) | Needed for |
| --- | --- |
| `VM.Allocate`, `VM.Clone` | create a VM / clone it from a template |
| `VM.Config.CPU/Memory/Disk/Network/Options` | set cores, memory + ballooning, disks, NIC, general options |
| `VM.Config.CDROM` | the cloud-init drive is a virtual CD-ROM (`ide2 … media=cdrom`) |
| `VM.Config.Cloudinit` | cloud-init settings (user, SSH keys, IP config) |
| `VM.Config.HWType` | serial console, VGA, SCSI controller type |
| `VM.PowerMgmt` | start / stop / shutdown the VM |
| `VM.Audit` | read VM config/status |
| `VM.GuestAgent.Audit` | read the guest agent's reported IPs (read-only; **not** `.Unrestricted`) |
| `Datastore.AllocateSpace`, `Datastore.Audit` | allocate the VM disk; read datastore info |
| `SDN.Use`, `Sys.Audit` | use the network bridge; read node/datastore inventory |

> **Note (PVE 9):** `VM.Monitor` was intentionally omitted — it is invalid on Proxmox VE 9
> and the `bpg/proxmox` provider never uses the QEMU monitor. The role is refined
> iteratively: start minimal, add a privilege when Terraform returns a `403 … Permission
> check failed (…, <Privilege>)`. The list above is the settled set for cloning a
> cloud-init VM template.

To update an existing role (e.g. after adding a privilege), replace the list with:

```bash
sudo pveum role modify TerraformProv -privs "…same list…"
```

## 2. Create the API-only user and token

```bash
sudo pveum user add terraform@pve                                   # API-only user in the 'pve' realm
sudo pveum user token add terraform@pve terraform-token --privsep 0 # prints the secret ONCE
```

`--privsep 0` (privilege separation off) makes the token inherit the user's role directly,
so the ACL below only needs to target the user. The command prints a `value` (the token
secret) exactly once — copy it now; it cannot be retrieved again (only regenerated).

## 3. Grant the role on the resource tree

```bash
sudo pveum acl modify / -user terraform@pve -role TerraformProv
```

## 4. Verify

```bash
sudo pveum role list | grep TerraformProv
sudo pveum user token list terraform@pve
sudo pveum acl list | grep terraform
```

## Wiring into Terraform

The provider reads the endpoint + token from variables; the **real values live only in a
gitignored `terraform/terraform.tfvars`** (never committed):

```hcl
proxmox_endpoint  = "https://<HOST_IP>:8006/"
proxmox_api_token = "terraform@pve!terraform-token=<SECRET>"
```

Store the master copy of the token secret in the secrets vault / password manager, not in
git. If it ever leaks, delete and recreate the token:

```bash
sudo pveum user token remove terraform@pve terraform-token
sudo pveum user token add terraform@pve terraform-token --privsep 0
```
