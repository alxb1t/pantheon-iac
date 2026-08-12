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

### Security
- Proxmox access for Terraform uses a dedicated least-privilege role (`TerraformProv`)
  and a scoped API token rather than the root account; real endpoint/token live only in
  a gitignored `terraform.tfvars` (Phase 1).

[Unreleased]: https://github.com/alxb1t/pantheon-iac
