# Create archlinux vm files

### 1. Pacstrap the archsystem to a file `archlinux.rootfs.ext4`
 
In order to run a guest vm based on archlinux we can can use [pacstrap](https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux)

``` bash
# create a directory
mkdir our_arch_vm
cd our_arch_vm

# create a sparse (assuming supported by the containing filesystem) 20G 
# file to use for the archlinux VM's rootfs 
truncate --size=20G archlinux.rootfs.ext4

# create a ext4 filesystem on the sparse file
mkfs.ext4 archlinux.rootfs.ext4

# let us have a mountpoint
mkdir ./mountpoint

# mount the file
sudo mount ./archlinux.rootfs.ext4 ./mountpoint

# use pacstrap to install a base system and some packages 
# (the `-c` uses the cache of your archlinux host
sudo pacstrap -c ./mountpoint base linux bash openssh bash-completion systemd vim tmux pv sudo
```

### 2. arch-chroot into te system to make virtio_mmio module being added to the initrd 

``` bash
# go into the newly generated arch guest vm 
sudo arch-chroot ./mountpoint 
```

Then inside the system of the new arch linux guest (vm)

``` bash
# we need to add the vitio_mmio and ext4 kernel modules to initrd
sed -i 's/MODULES=(/MODULES=(virtio_mmio ext4 /' /etc/mkinitcpio.conf

# then we will update the initrd
mkinitcpio -P

# set password for root in generate a user
passwd 

# optionally create new user
useradd archuser -m -s /bin/bash

# set the password fuer archuser
passwd archuser 

# leave the chroot
exit
```

### 3. extract the initramdisk and kernel to use with firecracker

``` bash
# copy the newly created initrd
sudo cp ./mountpoint/boot/initramfs-linux.img ./archlinux.initrd
# assign file to user 
sudo chown "$(whoami)" ./archlinux.initrd

# get the script to extract the vmlinux uncompressed from the bzImage linux kernel as
# provided by archlinux's package linux
curl https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux > extract-vmlinux.sh

# make it executable
chmod u+x extract-vmlinux.sh

# copy the kernel image file (compressed most likely bzImage) 
sudo cp ./mountpoint/boot/vmlinuz-linux ./ 
# adjust ownership
sudo chown "$(whoami)" ./vmlinuz-linux


# extract the uncompressed linux file (an ELF file for x86 platform)
./extract-vmlinux.sh ./vmlinux-linux > ./archlinux.vmlinux
```

### 4. cleanup / unmount
``` bash
sudo rm ./vmlinux-linux
sudo umount ./mountpoint
```


 
