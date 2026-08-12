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

[Unreleased]: https://github.com/alxb1t/pantheon-iac
