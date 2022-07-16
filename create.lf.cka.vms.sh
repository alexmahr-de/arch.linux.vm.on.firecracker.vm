#!/bin/bash

set -xueo pipefail

SCRIPTNAME="$0"
SCRIPTDIR="$(realpath "$(dirname "$SCRIPTNAME")")"

fail() {
    echo "${1:-unknown error}" >&2
    exit "${2:-1}"
}

usage() {
   test -z "${1:-}" || echo "$1" >&2
   fail "usage: $SCRIPTNAME <output directory>"
}

VM_OUTPUT_DIR="$1"
ROOTFS='rootfs.ext4'

# and to prevent undesired overwriting of files or merely that the provided 
# output directory already exists as any other type of file (socket, regular file etc....)
# we need to check 
test ! -e "$VM_OUTPUT_DIR" || fail "error: <output directory> "$VM_OUTPUT_DIR" must not yet exist"

# at this point now we are reasonably sure it exists...
mkdir -p "$VM_OUTPUT_DIR"

# and can change the current working directoy to it 
# this way all generated files are generated in the output dir
cd "$VM_OUTPUT_DIR"

# create a sparse (assuming supported by the containing filesystem) 20G 
# file to use for the archlinux VM's rootfs 
truncate --size=20G "$ROOTFS"

# create a ext4 filesystem on the sparse file
mkfs.ext4 "$ROOTFS"

# let us have a mountpoint
mkdir -p ./mountpoint

# mount the file
sudo mount ./"${ROOTFS}" ./mountpoint

#create a debootstrap cache 
# focal = ubuntu 20.04
mkdir -p /tmp/debootstrap.cache

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

sudo umount ./mountpoint


ssh-keygen -t rsa -b 4096 -q -N "" -f student.rsa.ssh.key.pem -C student

#cp = control-plain = "master" 
#worker 
for HOST in cp worker
do
  
  mkdir -p "$HOST"/mountpoint
  cp --reflink=always "$ROOTFS" "$HOST"/
  cp "$SCRIPTDIR"/lf.cka."$HOST".config.json "$HOST"/config.json
  sudo mount "$HOST"/"$ROOTFS" "$HOST"/mountpoint
   
  
  sudo tee "$HOST"/mountpoint/root/setup.sh << EOF
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

# optionally create new user
useradd  -m -s /bin/bash student 


# set the locale 
printf 'LC_ALL=C.UTF-8\\nLANG=C.UTF-8\\n' >> /etc/default/locale

# set apt-sources

echo '
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
' > /etc/apt/sources.list

sed '/^HISTSIZE=/d;/^HISTFILESIZE=/d;/^HISTCONTROL=/d' -i /etc/skel/.bashrc

echo '
HISTSIZE=-1
HISTFILESIZE=-1
HISTCONTROL=histappend
HISTTIMEFORMAT="%F %T: "
# enable bash completion in interactive shells
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
' >> /etc/bash.bashrc


echo 'student ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
su - student bash -c 'umask 0077
mkdir .ssh
touch .ssh/authorized_keys
echo "$(cat student.rsa.ssh.key.pem.pub)" >> .ssh/authorized_keys'

echo "$HOST" > /etc/hostname

# enable systemd-networkd
ln -sf /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/default.target.wants/

echo '
[Match]
Name=eth0

[Network]
DHCP=yes
' >   /etc/systemd/network/eth0.network


# make student having to set a passwort (optionally)
chage -d0 student
passwd -d student

# leave the chroot
exit
EOF
  
  # go into the newly generated arch guest vm 
  sudo arch-chroot "$HOST"/mountpoint /bin/bash /root/setup.sh
  sudo umount "$HOST"/mountpoint
done

rm "$ROOTFS"
rmdir  mountpoint
