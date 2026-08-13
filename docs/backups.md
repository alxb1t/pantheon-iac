# Backups & restore (Gitadel VM)

How the Gitadel VM is backed up and restored on Proxmox. The `bpg` Terraform provider has
**no backup-job resource**, so this is managed with the Proxmox CLI (`pvesh` / `vzdump`) and
documented here rather than in `terraform/`.

Two complementary layers:

| Layer | Tool | Scope | Restore target |
| --- | --- | --- | --- |
| **Infrastructure** | `vzdump` (this doc) | Whole VM (OS, Docker, Forgejo, data) | Proxmox only (`qmrestore`) |
| **Application** (future) | `forgejo dump` | Forge data only (repos, DB, issues/PRs, users, LFS) | **Any** Forgejo, any host — portable/off-site |

## Nightly backup job

VM `100` → `backup` storage (a Directory store on the second disk, `sdb`), nightly at
02:30, keeping the last 7:

```bash
sudo pvesh create /cluster/backup \
  --vmid 100 \
  --storage backup \
  --schedule "02:30" \
  --mode snapshot \
  --compress zstd \
  --prune-backups "keep-last=7" \
  --enabled 1

# list / verify the job
sudo pvesh get /cluster/backup --output-format yaml
```

- `--mode snapshot` — backs the VM up **live** (no downtime); uses the QEMU guest agent to
  briefly `fsfreeze` for a consistent SQLite/repo state.
- `--storage backup` — a **separate physical disk** (`sdb`) from the VM's disk (`sda`), so a
  single-disk failure doesn't take both. (Same chassis, though — see "Off-site" below.)

## Manual (on-demand) backup

```bash
sudo vzdump 100 --storage backup --mode snapshot --compress zstd
sudo ls -lh /mnt/backup/dump/     # vzdump-qemu-100-<timestamp>.vma.zst
```

## Restore

```bash
sudo qmrestore /mnt/backup/dump/vzdump-qemu-100-<timestamp>.vma.zst <vmid> --storage local-lvm
sudo qm start <vmid>
```

Two caveats learned the hard way:

1. **The restored VM boots with the *baked* static IP.** cloud-init does **not** re-run on a
   restore (same instance-id), so the guest keeps its original IP. Restoring it while the
   original VM is still running causes an **IP (and MAC) conflict**. Either stop/destroy the
   original first, or — to test a backup without touching production — restore to a
   **throwaway VMID** and check it there.

2. **Restoring a Terraform-managed VM desyncs the state.** A `qmrestore`d VM exists outside
   Terraform's state; a later `terraform apply` would try to create it again and clash. For
   restore *drills*, use a scratch VMID and destroy it after. To genuinely adopt a restored
   VM back under Terraform, `terraform import` it into state.

## Verifying a backup (restore drill)

The only backup you trust is one you've restored:

```bash
# with the original VM stopped/destroyed (frees the IP), restore to a scratch VMID:
sudo qmrestore /mnt/backup/dump/vzdump-qemu-100-<ts>.vma.zst 999 --storage local-lvm
sudo qm start 999
# ~1 min later the Docker service + Forgejo container auto-start; confirm the forge answers
curl -sS -o /dev/null -w "%{http_code}\n" http://<VM_IP>:3000/   # 200, and your repos are present
sudo qm stop 999 && sudo qm destroy 999 --purge
```

This also confirms Docker survives a clean boot (the netfilter modules load at boot).

## Off-site (a gap to close)

`vzdump` lands on `sdb` — the **same chassis** as the VM — so it does **not** protect against
whole-machine loss (fire/theft). The portable complement is **`forgejo dump`** (an archive
restorable onto any Forgejo instance, anywhere), shipped off-box on a schedule. Planned for
v0.2.
