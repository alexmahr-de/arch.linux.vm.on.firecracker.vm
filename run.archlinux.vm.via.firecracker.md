# Run archlinux vm via firecracker

Assuming we followed [create.arch.linux.vm.files.md](https://github.com/alexmahr-de/arch.linux.vm.on.firecracker.vm/blob/master/create.arch.linux.vm.files.md)
we should have a directory `our_arch_vm`

``` bash
# change into directory created before
cd our_arch_dir
```

### 1. in case needed get firecracker
(roughly following https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md )

``` bash
# in archlinux granting access to /dev/kvm  (needed for firecracker)
sudo usermod -a -G kvm "$(whoami)"


# get the firecracker binary 
test -x ./firecracker || {
  release_url="https://github.com/firecracker-microvm/firecracker/releases"
  latest=$(basename $(curl -fsSLI -o /dev/null -w  %{url_effective} ${release_url}/latest))
  arch=`uname -m`
  curl -L ${release_url}/download/${latest}/firecracker-${latest}-${arch}.tgz \
  | tar -xz
  mv release-${latest}-$(uname -m)/firecracker-${latest}-$(uname -m) ./firecracker
}
rm -f archlinux.vm.firecracker.unix.socket

cat > archlinux.vm.config.json << 'EOF'
{
  "boot-source": {
    "initrd_path": "archlinux.initrd",
    "kernel_image_path": "archlinux.vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off modules=virtio_mmio,ext4 rootfstype=ext4"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "archlinux.rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 1024
  }
}
EOF

./firecracker --api-sock archlinux.vm.firecracker.unix.socket \
  --config-file archlinux.vm.config.json

```
