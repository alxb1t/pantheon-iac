# Alpine cloud-init on Proxmox — gotchas & fixes

Notes from making the **Alpine generic cloud image** work as a cloud-init VM template on
Proxmox VE. Alpine is deliberately minimal (musl, BusyBox, OpenRC — no systemd, no PAM),
which makes it a great small Docker host but means its cloud-init path has sharp edges that
Debian/Ubuntu images hide. Each gotcha below is written as **symptom → cause → fix**, with
the fix as implemented in this repo.

Image used: `generic_alpine-<ver>-x86_64-bios-cloudinit-r0.qcow2`
(`generic` = generic-hypervisor / NoCloud datasource; `bios` = SeaBIOS, Proxmox's default).
Proxmox presents cloud-init as a NoCloud CD-ROM (`ide2`, label `cidata`).

---

## 1. Serial console is mandatory

- **Symptom:** the VM boots but the Proxmox "Console" is blank / appears to hang; hard to
  see boot output.
- **Cause:** Alpine cloud images expect a **serial console** (`console=ttyS0`); without a
  serial device they give you nothing to look at.
- **Fix:** attach a serial device and route the display to it. In the template build:
  `qm set … --serial0 socket --vga serial0`. In Terraform: a `serial_device {}` block plus
  `vga { type = "serial0" }`.
- Watch it live with `qm terminal <vmid>` (exit with `Ctrl+O`).

## 2. The QEMU guest agent is not preinstalled

- **Symptom:** Proxmox never shows the VM's IP; `qm agent <vmid> network-get-interfaces`
  says *"QEMU guest agent is not running"*; a Terraform `bpg` apply hangs waiting for the
  agent.
- **Cause:** the base image doesn't ship `qemu-guest-agent`.
- **Fix:** install + enable it on first boot via cloud-init **vendor-data**
  (`cloud-init/vendor-data.yml`): `packages: [qemu-guest-agent]`, then a `runcmd` to
  `rc-update add qemu-guest-agent default` and `rc-service qemu-guest-agent start`
  (OpenRC — Alpine has no systemd). Enable the agent on the VM too (`--agent enabled=1`).
- **Tip:** give the `bpg` VM resource an `agent { timeout = "5m" }` so a genuinely broken
  agent fails fast instead of hanging on the default 15-minute wait.

## 3. Key-based SSH is refused even with a correct key (no PAM)

- **Symptom:** the public key is present in `~/.ssh/authorized_keys` with correct
  permissions, `sshd -T` shows `pubkeyauthentication yes` — yet login gives
  `Permission denied (publickey)`.
- **Cause:** Alpine's OpenSSH is built **without PAM**. When cloud-init creates the user
  with no password, the account is **locked** (`!` in `/etc/shadow`), and non-PAM OpenSSH
  refuses locked accounts *even for key auth*. (Debian/Ubuntu allow it because PAM handles
  the account — which is why this surprises people.)
- **Fix:** unlock the account (change `!` → `*`, which still forbids password login but
  clears the lock). Done in `vendor-data.yml` `runcmd`, selecting users by UID so it works
  for whatever per-clone username Proxmox created:
  ```sh
  awk -F: '$3>=1000 && $3<65534{print $1}' /etc/passwd \
    | while read u; do sed -i "s/^$u:!:/$u:*:/" /etc/shadow; done
  ```

## 4. Static IP ⇒ no DNS (`/etc/resolv.conf` missing)

- **Symptom:** with a **static** IP, `ping 1.1.1.1` works but `ping <hostname>` fails with
  `bad address`; `apk` can't reach the mirrors, so the guest-agent install fails and
  first-boot setup stalls. Works fine with DHCP.
- **Cause:** with DHCP, Alpine's `udhcpc` writes `/etc/resolv.conf`. With a static address
  there's no DHCP client, and Alpine's cloud-init brings up the interface + route but does
  **not** write `resolv.conf`.
- **Fix:** write it early — `bootcmd` runs *before* the package stage, so DNS is in place
  when `apk` runs (`cloud-init/vendor-data.yml`):
  ```yaml
  bootcmd:
    - echo "nameserver 1.1.1.1" > /etc/resolv.conf
    - echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  ```

## 5. `doas`, not `sudo` — and no rule by default

- **Symptom:** `sudo` isn't installed (the MOTD says so); cloud-init logs
  `Invalid doas rule … not writing any doas rules for user!`, so the cloud user can't
  escalate — which blocks Ansible's privilege escalation.
- **Cause:** Alpine ships `doas` instead of `sudo`, and the image's default doas config
  doesn't apply to the cloud-init user.
- **Fix:** grant escalation in `vendor-data.yml` (root, on first boot — Ansible can't do
  this itself: it needs root to grant root). Install `doas`, add human users to the `wheel`
  group, and write a passwordless rule:
  ```sh
  awk -F: '$3>=1000 && $3<65534{print $1}' /etc/passwd | while read u; do adduser "$u" wheel; done
  echo "permit nopass :wheel" > /etc/doas.conf
  ```
  Ansible then escalates with `become_method: doas`. (`permit nopass :wheel` is the `doas`
  equivalent of `NOPASSWD` sudo — fine for a homelab VM.)

---

## Debugging when you're locked out (no SSH, no agent)

When a clone won't accept SSH and the agent isn't up, you still have options:

- **`qm guest exec <vmid> -- <cmd>`** — run commands *inside* the guest through the agent,
  no SSH needed. (Requires the agent to be running — useless if that's what's broken.)
- **Serial console:** `qm terminal <vmid>` shows boot + cloud-init output. To actually log
  in, spin a **throwaway debug clone with a console password**:
  `qm set <id> --ciuser <u> --cipassword <pw> --ipconfig0 … --nameserver …`, then log in on
  the console and read logs.
- **Cloud-init logs & state (inside the guest):**
  - `cloud-init status --long` — done vs. still-running, plus recoverable errors.
  - `/var/log/cloud-init.log` — module-by-module debug trace.
  - `/var/log/cloud-init-output.log` — stdout/stderr of `bootcmd`/`runcmd` (host keys,
    `apk`, service starts).
  - `rc-status` — which OpenRC services actually started (`sshd`, `qemu-guest-agent`, …).
- **IP conflicts:** if a VM is intermittently unreachable, another device may hold its IP.
  From the Proxmox host: `sudo arping -c3 -w3 -I vmbr0 <ip>` — a MAC reply means it's taken.
  See `ip-addressing.md`.

## Where the fixes live in this repo

| Fix | File |
| --- | --- |
| Serial console, disk import, cloud-init drive, template build | `cloud-init/build-alpine-template.sh` |
| Guest agent install, account unlock, early DNS (`bootcmd`) | `cloud-init/vendor-data.yml` |
| Agent enable + `timeout`, serial device, static IP, cloud-init identity | `terraform/gitadel-vm.tf` |
| Least-privilege Proxmox token (incl. `VM.Config.CDROM`, `VM.GuestAgent.Audit`) | `docs/terraform-proxmox-access.md` |
| Choosing a conflict-free static IP | `docs/ip-addressing.md` |
