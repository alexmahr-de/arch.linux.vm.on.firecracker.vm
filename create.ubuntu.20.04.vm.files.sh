#!/bin/bash

set -xueo pipefail

SCRIPTNAME="$0"

fail() {
    echo "${1:-unknown error}" >&2
    exit "${2:-1}"
}

usage() {
   test -z "${1:-}" || echo "$1" >&2
   fail "usage: $SCRIPTNAME <output directory> [VM disk size in GiB] [VM RAM size in MiB]" 
}


cleanup() {
   grep "$(realpath ./mountpoint)" /proc/mounts 
   sudo umount ./mountpoint;
}
trap cleanup EXIT

VM_OUTPUT_DIR="${1:-}"
VM_DISK_GB="${2:-20}"
VM_RAM_MB="${3:-1024}"

# we require a output directory 
test -n "$VM_OUTPUT_DIR" || usage "error: no <output directory> provided"

# and to prevent undesired overwriting of files or merely that the provided 
# output directory already exists as any other type of file (socket, regular file etc....)
# we need to check 
test ! -e "$VM_OUTPUT_DIR" || fail "error: <output directory> "$VM_OUTPUT_DIR" must not yet exist"

# the provided $VM_DISK_GB must be at least reasonable hence > 2GiB 
test "$VM_DISK_GB" -ge "2" || fail "error: the provided \$VM_DISK_GB is incorrect. It must be at least 2GiB"

# at this point now we are reasonably sure it exists...
mkdir -p "$VM_OUTPUT_DIR"
# and can change the current working directoy to it 
# this way all generated files are generated in the output dir
cd "$VM_OUTPUT_DIR"

# allowing a prefix to e used via environmental variable
PREFIX="${PREFIX:-ubuntu}"
VMHOSTNAME="${VMHOSTNAME:-${PREFIX}vm}"

# which however cannot contain a '/' as it should be a filename
test "${PREFIX}" == "$(basename "${PREFIX}")" || fail "error: incorrect \$PREFIX \"$PREFIX\" "

# with the prefix we now set the filename for the file containing the rootfs for the guest 
ROOTFS="${PREFIX}.rootfs.ext4"

# create a sparse (assuming supported by the containing filesystem) 20G 
# file to use for the archlinux VM's rootfs 
truncate --size="$VM_DISK_GB"G "$ROOTFS"

# create a ext4 filesystem on the sparse file
mkfs.ext4 "$ROOTFS"

# let us have a mountpoint
mkdir -p ./mountpoint

# mount the file
sudo mount ./"${ROOTFS}" ./mountpoint

#create a debootstrap cache 
# focal = ubuntu 20.04
mkdir -p /tmp/debootstrap.cache

#
PACKAGES="$( { head -c -1 | tr '\n' ',' | tr -d ' '; } << 'EOF'
initramfs-tools
openssh-sftp-server
openssh-server
sudo
wget
curl
gnupg
linux-image-kvm
bash
bash-completion
nano
vim
tasksel 
EOF
)"

sudo debootstrap --cache-dir=/tmp/debootstrap.cache \
    --arch=amd64 --include="$PACKAGES" focal ./mountpoint \
    http://archive.ubuntu.com/ubuntu



sudo tee ./mountpoint/root/setup.sh << EOF
#!/bin/bash
set -x
PATH="/sbin:\$PATH"

# disable the fallback initrd of arch
systemctl enable multi-user.target
systemctl enable multi-user.target 2>/dev/null
systemctl set-default multi-user.target
echo 'kernel.pid_max = 32768' >> /etc/sysctl.conf

# then we will update the initrd
update-initramfs -k all -c

# set password for root in generate a user
passwd 

# optionally create new user
useradd -G sudo  -m -s /bin/bash archuser

# set the password fuer archuser
passwd archuser 

echo "$VMHOSTNAME" > /etc/hostname

# leave the chroot
exit
EOF
#sudo sed -i 's/{HOSTNAME}/'"$HOSTNAME"'/' ./mountpoint/root/setup.sh

# go into the newly generated arch guest vm 
sudo arch-chroot ./mountpoint /bin/bash /root/setup.sh



