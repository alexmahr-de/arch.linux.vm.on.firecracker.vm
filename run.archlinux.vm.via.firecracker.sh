!#/bin/bash
# (C)opyright Alexander Mahr 2022 
# GPLv3 license
# description: Use firecracker "hypervizor: to run archlinux vm

set -xueo pipefail

SCRIPTNAME="$0"
CONFIGTEMPLATE="$(dirname "$(realpath "$SCRIPTNAME")")/firecracker.vmconfig.json"

echo "$CONFIGTEMPLATE"
stat "$CONFIGTEMPLATE"
fail() {
    echo "${1:-unknown error}" >&2
    exit "${2:-1}"
}

usage() {
   test -z "${1:-}" || echo "$1" >&2
   fail "usage: $SCRIPTNAME <archlinux.vm directory> [VM RAM size in MiB]" 
}

cleanup() {
   test -f vmlinuz-linux && rm vmlinuz-linux
   test -n "{APISOCKET:-}" && test -e "$APISOCKET" && rm "$APISOCKET"
   sudo umount ./mountpoint || true
}

trap cleanup EXIT

VM_OUTPUT_DIR="${1:-}"
VM_RAM_MB="${3:-1024}"
# allowing a prefix to e used via environmental variable
PREFIX="${PREFIX:-archlinux}"
# which however cannot contain a '/' as it should be a filename
test "${PREFIX}" == "$(basename "${PREFIX}")" || {
fail "error: incorrect \$PREFIX \"$PREFIX\" "
}

# we require a output directory 
test -n "$VM_OUTPUT_DIR" || usage "error: no <output directory> provided"

# and to prevent undesired overwriting of files or merely that the provided 
# output directory already exists as any other type of file (socket, regular file etc....)
# we need to check 
test ! -f "$VM_OUTPUT_DIR" || {
    fail "error: <output directory> "$VM_OUTPUT_DIR" must not yet exist"
}

test -f "$CONFIGTEMPLATE" || {
    fail "error: the firecracker config at '$CONFIGTEMPLATE' not found"
}

# at this point now we are reasonably sure it exists...
mkdir -p "$VM_OUTPUT_DIR"
# and can change the current working directoy to it 
# this way all generated files are generated in the output dir
cd "$VM_OUTPUT_DIR"


# with the prefix we now set the filename for the file containing the rootfs for the guest 
ROOTFS="${PREFIX}.rootfs.ext4"
KERNEL="${PREFIX}.vmlinux.elf"
INITRD="${PREFIX}.initrd"
APISOCKET="${PREFIX}.api.unix.socket"
CONFIG="${PREFIX}.config.json"

# let us have a mountpoint
mkdir -p ./mountpoint

# mount the file
sudo mount ./"$ROOTFS" ./mountpoint


# get GPLv2 licensed shell script from linux kernel source that gets an uncompressed
# version of the linux kernel binary (i.e. ELF format for x86
test -f extract-vmlinux.sh || {
    wget -O extract-vmlinux.sh \
    https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux
    chmod u+x extract-vmlinux.sh
}

# get APACHE licensed firecracker binary 
test -x ./firecracker || (
    release_url="https://github.com/firecracker-microvm/firecracker/releases"
    latest=$(basename $(curl -fsSLI -o /dev/null -w  %{url_effective} ${release_url}/latest))
    arch=`uname -m`
    curl -L ${release_url}/download/${latest}/firecracker-${latest}-${arch}.tgz \
    | tar -xz
    mv release-${latest}-$(uname -m)/firecracker-${latest}-$(uname -m) ./firecracker
) || {
    fail "error :  could not get firecracker binary"
}

sudo cp ./mountpoint/boot/vmlinuz-linux ./
sudo chown "$(whoami)" vmlinuz-linux
sudo cp ./mountpoint/boot/initramfs-linux.img ./$INITRD
sudo chown "$(whoami)" "$INITRD"


# extract the kernel
./extract-vmlinux.sh  vmlinuz-linux > ./"$KERNEL"
rm vmlinuz-linux

cp "$CONFIGTEMPLATE" "$CONFIG"

for VAR in KERNEL ROOTFS INITRD VM_RAM_MB
do 
    sed -i 's/{'"$VAR"'}/'"${!VAR}"'/' "$CONFIG"
done

# unmount the archlinux guest ext4 fs
sudo umount ./mountpoint

# remove unix-socket if necessary
test -e "$APISOCKET" && rm "$APISOCKET"

# run the vm in firecracker unsafely (as it is not using jailer)
./firecracker --api-sock "$APISOCKET" --config-file "$CONFIG"


