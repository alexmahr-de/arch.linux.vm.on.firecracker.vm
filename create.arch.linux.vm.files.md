# Create archlinux vm files

## 1. Pacstrap the archsystem to a file `archlinux.rootfs.ext4`
 
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

# use pacstrap 
archlinux.rootfs.ext4

# use pacstrap to install a base system and some packages (the `-c` uses the cache of your archlinux host
pacstrap -c ./mountpoint base linux bash openssh bash-completion systemd vim tmux pv sudo
```

## 2. arch-chroot into te system to make virtio_mmio module being added to the initrd 

``` bash
#go into the newly generated arch guest vm 
arch-chroot ./mountpoint 

# inside the system of the new arch linux guest (vm)
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
```


 
