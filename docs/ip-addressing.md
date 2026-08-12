# Static IP addressing on the LAN

VMs in this project get a **static IP** via cloud-init (see `terraform/` `vm_ip`). A static
address must be (1) inside the subnet, (2) outside the router's DHCP pool, and (3) not
already in use. Skip any of these and you get an **IP conflict** — two hosts claiming the
same address, which makes the VM intermittently unreachable and hard to diagnose.

Replace the example values below with your own; real topology stays out of this repo.

## 1. Understand the subnet

A home LAN is usually a **/24**: 256 addresses, `A.B.C.0`–`A.B.C.255`.

- `.0` = network address, `.255` = broadcast — **reserved, never assign.**
- The router/gateway takes one address (commonly `.1` or `.254`).
- Everything else in `.1`–`.254` (minus the gateway) is a usable host address.

Find yours from any host on the LAN (e.g. the Proxmox host):

```bash
ip -4 addr show        # your address + prefix, e.g. 192.0.2.10/24  → /24 = 256 addresses
ip route               # "default via <gateway>" → the router's address
```

## 2. Find the DHCP pool (the range to AVOID for statics)

The router leases addresses from a **DHCP pool** — a contiguous range it hands out
automatically (e.g. `.100`–`.199`). If you put a static IP **inside** that pool, the router
may lease the same address to another device → conflict. So statics must live **outside**
the pool.

Where to find it: router admin UI → **LAN / DHCP settings** → "DHCP range" / "address pool"
/ "start–end".

Example (illustrative, not this network):

| Item | Value |
| --- | --- |
| Subnet | `192.168.1.0/24` |
| Gateway | `192.168.1.1` |
| DHCP pool | `192.168.1.100 – 192.168.1.199` |
| **Safe static block** | `192.168.1.2 – .99` and `.200 – .254` |

## 3. Verify the address is actually free — *right before* assigning

"Outside the DHCP pool" is necessary but **not sufficient**: another statically-configured
device (or a device with a randomized MAC) may already be sitting there. Always probe the
candidate from a host on the LAN — the Proxmox host is ideal (`vmbr0` is the LAN bridge):

```bash
# ARP probe — layer 2, catches hosts that ignore ping
sudo arping -c3 -w3 -I vmbr0 <candidate-ip>
# ICMP, as a second opinion
ping -c3 -W1 <candidate-ip>
```

Reading the result:

- **A reply with a MAC address → the IP is TAKEN.** Pick another.
- **All `Timeout` / `0 received` → free right now.**

Trust **ARP** over ping: it asks "who has this IP?" at the Ethernet layer, so even a host
that drops pings reveals itself.

> Caveat: ARP shows only what's *live this moment*. A powered-off device could return, and a
> future DHCP lease could collide. That's why statics must also sit outside the DHCP pool,
> and why you keep a record (below).

## 4. Keep an allocation record

Track what you've assigned so you don't collide with yourself. Keep this **out of the public
repo** if it contains real addresses (it's network topology):

| IP | Assigned to |
| --- | --- |
| `.1` / `.254` | gateway |
| `.NN` | Proxmox host |
| `.NN` | service VM (e.g. the forge) |

## Checklist before setting a VM's `vm_ip`

1. Inside the subnet? (matches your `/prefix`)
2. Not the network (`.0`), broadcast (`.255`), or gateway address?
3. Outside the DHCP pool? (router UI)
4. `arping` silent *right now*?

All four "yes" → safe to assign.
