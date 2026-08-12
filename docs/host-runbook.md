# Pantheon — Host Runbook

Reproducible host-setup steps for the Proxmox VE 9.2 host that Pantheon runs on.
This is the manual "day zero" foundation the Infrastructure-as-Code builds on top of:
Terraform/Ansible/cloud-init assume a host prepared as described below.

> **Conventions used in this runbook**
> - `<HOST_IP>` — the host's static LAN IP.
> - `<GATEWAY_IP>` — the LAN gateway / DNS server.
> - `<LAN_SUBNET>` — the LAN subnet in CIDR form (e.g. `10.0.0.0/24`).
> - Replace these with your own values; the real ones are kept out of this public repo.
> - Commands are run on the **host console/SSH as root** unless a step says otherwise
>   (Mac workstation steps are called out explicitly).

## Stage: Setup Proxmox (host config)

### 1. Prevent sleep when the laptop lid is closed
The host is a laptop that runs lid-closed; it must never suspend. Validated for
Proxmox VE 9.2 (Debian 13, systemd v257).

Edit `/etc/systemd/logind.conf`:
```ini
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
HandleLidSwitchExternalPower=ignore
```
Apply:
```bash
systemctl restart systemd-logind.service
```

**Why all three:** on modern systemd, lid behavior while on **AC power** is governed by
`HandleLidSwitchExternalPower=` (not `HandleLidSwitch=`). Since this host is always
plugged in, that one is the decisive setting. `HandleLidSwitchDocked=` covers the docked case.

_Optional — fully block every suspend path (not just the lid):_
```bash
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

### 2. Blank the console/display after idle
Turn the physical screen off after 300s of inactivity (power saving / avoid burn-in)
while the host keeps running.

Applies because this is an **ext4/LVM install → bootloader is GRUB**. Edit `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX="consoleblank=300"
```
Apply:
```bash
update-grub
```
Verify after reboot:
```bash
proxmox-boot-tool status   # reports GRUB / "not configured" for systemd-boot = GRUB in use
cat /proc/cmdline          # should contain consoleblank=300
```

**Caveat:** on a *ZFS-on-UEFI* install Proxmox uses **systemd-boot**, where
`/etc/default/grub` is ignored — you'd edit the kernel cmdline via `proxmox-boot-tool`
instead. Not applicable to this host (ext4), but noted for portability of the runbook.

> On a plain-GRUB (ext4) install, `proxmox-boot-tool status` returns
> `E: /etc/kernel/proxmox-boot-uuids does not exist` — that is the **expected** result and
> confirms proxmox-boot-tool is *not* managing boot. Verify the tweak took with
> `cat /proc/cmdline` showing `consoleblank=300`.

### 3. Switch to the no-subscription repository and update
A fresh install enables the **enterprise** repo, which returns `401 Unauthorized` on
`apt update` without a paid subscription. For a homelab, switch to the free
**no-subscription** repo, then patch the host. Proxmox VE 9 is on **Debian 13 "trixie"**
and uses the **deb822 `.sources`** format (not the old one-line `.list` entries from PVE 8).

Inspect first (confirm filenames):
```bash
ls -1 /etc/apt/sources.list.d/
# expect: pve-enterprise.sources  ceph.sources  debian.sources
```

Add the PVE no-subscription repo:
```bash
cat > /etc/apt/sources.list.d/pve-no-subscription.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

Disable the enterprise PVE repo (rewrite, disabled — idempotent):
```bash
cat > /etc/apt/sources.list.d/pve-enterprise.sources <<'EOF'
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: trixie
Components: pve-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
EOF
```

Disable the enterprise Ceph repo (single node, no Ceph — stops `apt update` 401s):
```bash
cat > /etc/apt/sources.list.d/ceph.sources <<'EOF'
Types: deb
URIs: https://enterprise.proxmox.com/debian/ceph-squid
Suites: trixie
Components: enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: false
EOF
```

Refresh, upgrade, reboot if the kernel changed:
```bash
apt update
apt full-upgrade -y
reboot   # only if a new kernel was installed
```

Verify:
```bash
apt update     # must complete with NO 401 Unauthorized
pveversion     # shows pve-manager + kernel version
```

**Notes:**
- `apt full-upgrade` is Proxmox's recommended upgrade verb (= `dist-upgrade`); plain
  `upgrade` can hold back kernel/package transitions.
- Debian base repos (`debian.sources`) are already correct — leave them.
- The "No valid subscription" login popup is cosmetic; suppressing it needs a fragile
  community patch that can re-break on updates — left off deliberately.

### 4. SSH key access + non-root admin user
Stop working as `root` over a password. Create a sudo-capable admin user (`alxb1t`),
log in with a **dedicated** SSH key, and lock down `sshd`. **Order matters:** confirm
key login works *before* disabling password auth, or you risk locking yourself out.
Keep an existing session open while changing `sshd`.

Create the admin user (host console, as root):
```bash
apt install -y sudo          # Proxmox doesn't always ship sudo
adduser alxb1t               # set a password + name
usermod -aG sudo alxb1t      # grant sudo
```

Create a **Proxmox-dedicated** SSH key on the workstation (Mac). A separate key can be
revoked/rotated without touching other keys:
```bash
ssh-keygen -t ed25519 -C "alxb1t@pantheon" -f ~/.ssh/pantheon_ed25519
```
- `-t ed25519` modern key type · `-C` label baked into the pubkey · `-f` dedicated
  filename (won't clobber the default `id_ed25519`). Passphrase recommended
  (ssh-agent/keychain can cache it).

Push the key and add an SSH alias (Mac):
```bash
ssh-copy-id -i ~/.ssh/pantheon_ed25519.pub alxb1t@<HOST_IP>

cat >> ~/.ssh/config <<'EOF'

Host pantheon
    HostName <HOST_IP>
    User alxb1t
    IdentityFile ~/.ssh/pantheon_ed25519
    IdentitiesOnly yes
EOF

ssh pantheon                 # MUST log in by key (no password) before continuing
```
`IdentitiesOnly yes` offers only this key (avoids "too many authentication failures").

Harden `sshd` (once key login is confirmed; keep a session open):
```bash
sudo tee /etc/ssh/sshd_config.d/10-hardening.conf >/dev/null <<'EOF'
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF
sudo sshd -t                  # syntax check (no output = OK)
sudo systemctl restart ssh
```
- `PermitRootLogin prohibit-password` keeps a **key-only** root fallback; tighten to `no`
  once comfortable on `alxb1t`.
- Reminder: an active **VPN on the workstation can make `<HOST_IP>` unreachable** — turn
  it off (or use split-tunnel / LAN bypass) for SSH/web UI.

Optional — give the PAM user web UI admin (stop using `root@pam` for the UI):
```bash
sudo pveum user add alxb1t@pam
sudo pveum acl modify / -user alxb1t@pam -role Administrator
```
Log into the web UI as `alxb1t`, realm **Linux PAM**.

> Verify password auth is actually off:
> `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no pantheon`
> should be refused with `Permission denied (publickey)`. Keep the console root password
> as the local fallback.

### 5. Second disk (`sdb`) as backup/ISO storage
Storage plan: `sda` runs VMs, `sdb` holds their backups + ISOs on a separate physical
disk. **Destructive to `sdb`** — confirm the target first.

Confirm the target disk (must be the empty second SSD, not `sda`):
```bash
lsblk          # sdb has no in-use partitions; sda holds the Proxmox LVM
```

Partition + format:
```bash
sudo wipefs -a /dev/sdb                       # clear stale signatures
sudo sgdisk -n1:0:0 -t1:8300 /dev/sdb         # one GPT partition, full disk, Linux FS
sudo mkfs.ext4 -L pantheon-backup /dev/sdb1
```

Mount persistently by UUID:
```bash
sudo mkdir -p /mnt/backup
UUID=$(sudo blkid -s UUID -o value /dev/sdb1)   # blkid is in /sbin (root PATH) → use sudo
echo "UUID=$UUID /mnt/backup ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo mount -a
df -h /mnt/backup
```
- `nofail` → host still boots if `sdb` is missing/failed (don't hang on the backup disk).
- Mount by **UUID**, not `/dev/sdb1`, to survive disk-order changes.

Register as Proxmox Directory storage:
```bash
sudo pvesm add dir backup --path /mnt/backup --content backup,iso,vztmpl
sudo pvesm status          # 'backup' should show active
```

Scheduled backup job (`Datacenter → Backup`) is added later, once there's a VM worth backing up.

### 6. Internal "KEYS" flash (`sdc`) as a LUKS-encrypted secrets vault
The laptop has an OEM internal USB flash disk (originally `LABEL "KEYS"`) — repurpose it
as an **on-demand, LUKS-encrypted vault** for secrets kept out of git (master `.env`
files, service credentials, break-glass recovery material). **Destructive to `sdc`.**

**Design constraints:**
- **Unlocked by hand, on demand** — deliberately *not* in `/etc/fstab` or `/etc/crypttab`.
  It stays locked at rest and while the host is unattended.
- **Consumer NAND, internal (same chassis)** — low-write use only; **never the sole copy**
  of any secret (also keep it in a password manager). Not off-site, so no DR value against
  whole-machine loss.

Confirm the target and peek at existing contents first (must be the `KEYS` flash, not `sda`/`sdb`):
```bash
lsblk -o NAME,SIZE,RM,TRAN,VENDOR,MODEL,LABEL /dev/sdc   # RM=1, TRAN=usb, MODEL "USB Flash Disk"
sudo mkdir -p /mnt/keys-check
sudo mount -o ro /dev/sdc1 /mnt/keys-check && ls -la /mnt/keys-check   # glance for anything worth keeping
sudo umount /mnt/keys-check
```

Wipe + create a single LUKS partition:
```bash
sudo apt install -y cryptsetup
sudo wipefs -a /dev/sdc
sudo sgdisk -Z /dev/sdc                        # zap old GPT/MBR
sudo sgdisk -n1:0:0 -t1:8309 /dev/sdc          # one partition, type 8309 = Linux LUKS
```

Format + open the LUKS container (LUKS2 default):
```bash
sudo cryptsetup luksFormat /dev/sdc1           # type YES, set a STRONG passphrase (store in password manager)
sudo cryptsetup open /dev/sdc1 keys            # maps to /dev/mapper/keys
sudo mkfs.ext4 -L KEYS /dev/mapper/keys
```

Mount, take ownership, use:
```bash
sudo mkdir -p /mnt/keys
sudo mount /dev/mapper/keys /mnt/keys
sudo chown alxb1t:alxb1t /mnt/keys
# … store secrets under /mnt/keys …
```

Lock it again when done:
```bash
sudo umount /mnt/keys
sudo cryptsetup close keys
```

**Unlock / lock cycle (day-to-day):**
```bash
# unlock
sudo cryptsetup open /dev/sdc1 keys && sudo mount /dev/mapper/keys /mnt/keys
# lock
sudo umount /mnt/keys && sudo cryptsetup close keys
```

**Back up the LUKS header off-device** (a corrupt header = permanently unrecoverable data).

Create the header backup on the host:
```bash
sudo cryptsetup luksHeaderBackup /dev/sdc1 --header-backup-file pantheon-keys-luks-header.img
sudo chown alxb1t:alxb1t ~/pantheon-keys-luks-header.img   # sudo-created → make it readable to scp
ls -l ~/pantheon-keys-luks-header.img
```

Transfer to the workstation (on the Mac, via the `pantheon` SSH alias), then remove it from the host:
```bash
scp pantheon:pantheon-keys-luks-header.img ~/Downloads/    # remote path is relative to /home/alxb1t
# --- back on the host ---
rm ~/pantheon-keys-luks-header.img                         # don't leave the header on the machine it protects
```

Store it safely on the workstation — **not** in `~/Downloads`. The header holds the
(passphrase-encrypted) key slots, so keep it encrypted and **separate from the drive**:
- Attach it to a password-manager entry alongside the LUKS passphrase (e.g.
  Strongbox/1Password/Bitwarden attachments), **or**
- Put it in an encrypted disk image (Disk Utility → New Image → 256-bit AES), then delete
  the `~/Downloads` copy.

**Notes:**
- Device name `sdc` can shift across reboots — always re-confirm with `lsblk`/`blkid`
  before any destructive command; for scripts, prefer `/dev/disk/by-id/…` or open by LUKS
  UUID (`sudo cryptsetup luksUUID /dev/sdc1`).
