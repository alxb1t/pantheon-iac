#!/bin/sh
# build-alpine-template.sh — bake a reusable Alpine Docker-host VM template on Proxmox.
# Run ON the Proxmox host as root (sudo). Re-runnable: rebuilds the VMID from scratch.
# Prereq: 'local' storage has the 'snippets' content type enabled.
set -eu

# --- Config (host-specific, but NO secrets — safe to commit) ---
VMID=9000
VMNAME="alpine-cloudinit-template"
DISK_STORAGE="local-lvm"          # lvmthin: VM boot disk + cloud-init drive
SNIPPET_STORAGE="local"           # dir storage with 'snippets' enabled
BRIDGE="vmbr0"

ALPINE_SERIES="v3.24"
ALPINE_IMG="generic_alpine-3.24.1-x86_64-bios-cloudinit-r0.qcow2"
ALPINE_SHA512="8d756f6fc7653daa4fb4e2e213d8a66007bcb1e5a846e28891af62c47b90685c694486c2746099ad99e9e8f5278db76b69d11dfe1e9361aa4c8406df16929a9c"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_SERIES}/releases/cloud/${ALPINE_IMG}"

WORKDIR="/var/lib/vz/template/qcow"
IMG_PATH="${WORKDIR}/${ALPINE_IMG}"
SNIPPET_DIR="/var/lib/vz/snippets"

# Resolve this script's own dir so we can copy vendor-data.yml sitting beside it.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# --- 1. Download + verify the Alpine cloud image ---
mkdir -p "$WORKDIR"
if [ ! -f "$IMG_PATH" ]; then
    echo ">>> downloading $ALPINE_IMG"
    wget -O "$IMG_PATH" "$ALPINE_URL"
fi
echo ">>> verifying checksum"
echo "${ALPINE_SHA512}  ${IMG_PATH}" | sha512sum -c -

# --- 2. Install the cloud-init vendor-data snippet ---
mkdir -p "$SNIPPET_DIR"
cp "${SCRIPT_DIR}/vendor-data.yml" "${SNIPPET_DIR}/vendor-data.yml"

# --- 3. (Re)create the VM shell ---
if qm status "$VMID" >/dev/null 2>&1; then
    echo ">>> VMID $VMID exists — destroying for a clean rebuild"
    qm destroy "$VMID" --purge
fi
echo ">>> creating VM $VMID"
qm create "$VMID" \
    --name "$VMNAME" \
    --memory 1024 \
    --cores 1 \
    --cpu host \
    --net0 virtio,bridge="$BRIDGE" \
    --scsihw virtio-scsi-single \
    --ostype l26 \
    --agent enabled=1 \
    --serial0 socket \
    --vga serial0

# --- 4. Import disk, attach cloud-init drive, set boot order + vendor-data ---
echo ">>> importing disk"
qm set "$VMID" --scsi0 "${DISK_STORAGE}:0,import-from=${IMG_PATH}"
qm set "$VMID" --ide2 "${DISK_STORAGE}:cloudinit"
qm set "$VMID" --boot order=scsi0
qm set "$VMID" --cicustom "vendor=${SNIPPET_STORAGE}:snippets/vendor-data.yml"

# --- 5. Freeze into a template ---
echo ">>> converting VMID $VMID to a template"
qm template "$VMID"

echo ">>> DONE — template '$VMNAME' (VMID $VMID) ready to clone."
