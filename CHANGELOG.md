# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pantheon v0.1 is built phase-by-phase; each completed phase adds entries under
[Unreleased]. When v0.1 ships (repo made public), these graduate into a tagged `0.1.0`.

## [Unreleased]

### Added
- Repository scaffolding: `CLAUDE.md` (loads project context from the notes vault),
  `.env.example` template, and `.gitignore` covering Terraform state/vars, `.env`,
  and SSH keys (Phase 0).
- Directory structure — `terraform/`, `ansible/`, `cloud-init/`, `docs/` (Phase 0).
- `docs/host-runbook.md`: reproducible Proxmox VE host setup (lid/sleep, console
  blanking, no-subscription repo, SSH hardening + non-root admin, backup disk, LUKS
  secrets vault), with home-network topology scrubbed to placeholders (Phase 0).
- `README.md`: project overview, architecture diagram (Mermaid), repository layout,
  and secrets/topology discipline (Phase 0).
- `CHANGELOG.md` following Keep a Changelog (Phase 0).
- `LICENSE`: MIT (Phase 0).
- Terraform ↔ Proxmox authentication: `bpg/proxmox` provider configured with a
  least-privilege, API-only token (`terraform@pve`, not root), plus a read-only node
  data source that verifies connectivity without changing infrastructure (Phase 1).
- `terraform/` inputs and reproducibility: `providers.tf`/`variables.tf`, a committed
  `terraform.tfvars.example` template, and a pinned `.terraform.lock.hcl` (Phase 1).
- Alpine cloud-init VM template on Proxmox: `cloud-init/build-alpine-template.sh` builds a
  reusable, generic Docker-host template — downloads + sha512-verifies the Alpine cloud
  image, creates a virtio VM with a serial console and cloud-init drive, imports the disk,
  wires in vendor-data, and converts it to a Proxmox template (Phase 2).
- `cloud-init/vendor-data.yml`: cloud-init vendor-data that installs `qemu-guest-agent` and
  unlocks the cloud-init user so key-based SSH works on Alpine (its OpenSSH is built without
  PAM and refuses `!`-locked accounts even with a valid key) (Phase 2).
- Gitadel VM declared in Terraform (`terraform/gitadel-vm.tf`): clones the Alpine template
  via `bpg` with 1 vCPU, memory ballooning (512–1024 MB), a 20 GB disk, a static IP, and
  cloud-init identity (user + SSH key); parameterized in `variables.tf`, with real values in
  the gitignored `terraform.tfvars` (Phase 3).
- `docs/terraform-proxmox-access.md`: documents the least-privilege Proxmox role, API-only
  user, and token setup for Terraform (Phase 3).
- `docs/ip-addressing.md`: how to choose a safe static IP — subnet, DHCP pool, and an
  `arping` free-address check (Phase 3).
- `docs/alpine-cloud-init-notes.md`: Alpine-on-Proxmox cloud-init gotchas & fixes (serial
  console, guest agent, no-PAM SSH lock, static-IP DNS, `doas`) + debugging techniques
  (Phase 3).
- Ansible project (`ansible/`): `ansible.cfg`, `site.yml`, and a gitignored `inventory.ini`
  (committed `inventory.example.ini`), using `doas` for privilege escalation (Phase 4).
- Ansible base role `docker-host`: installs Docker + the Compose plugin (Alpine
  `community`), loads Docker's netfilter kernel modules, enables the OpenRC service, and
  adds the login user to the `docker` group (Phase 4).
- Ansible deploy seam `gitadel-deploy`: checks out the vendor-neutral Gitadel repo onto the
  VM, templates its `.env`, and runs `docker compose up -d` (Forgejo on SQLite) (Phase 4).
- cloud-init: `doas` privilege escalation for the cloud user — install `doas`, add human
  users to `wheel`, `permit nopass :wheel` — so Ansible can `become` (Phase 4).

### Changed
- `terraform/gitadel-vm.tf`: set `initialization.upgrade = false` to skip the first-boot
  package upgrade, which on Alpine swapped the kernel out from under the running one and
  broke Docker's iptables/netfilter setup (Phase 4).

### Fixed
- Alpine VMs with a static IP had no DNS — cloud-init configures the interface but does not
  write `/etc/resolv.conf` (normally the DHCP client does). `vendor-data.yml` now writes it
  early via `bootcmd`, so `apk` (guest-agent install) works on first boot (Phase 3).

### Security
- Proxmox access for Terraform uses a dedicated least-privilege role (`TerraformProv`)
  and a scoped API token rather than the root account; real endpoint/token live only in
  a gitignored `terraform.tfvars` (Phase 1).

[Unreleased]: https://github.com/alxb1t/pantheon-iac
