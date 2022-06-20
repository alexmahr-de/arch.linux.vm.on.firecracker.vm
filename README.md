# arch.linux.vm.on.firecracker.vm
scripts related to run generate a arch linux VM to be run via firecracker

## What is firecracker?
oversimplified firecracker is virtualization software 
 - comparable to [QEMU](https://en.wikipedia.org/wiki/QEMU) as a software
   - running on linux kernel 
   - using linux KVM 
 - distinct to QEMU in 
   - being much smaller in [TCB](https://en.wikipedia.org/wiki/Trusted_computing_base) and hence potentially safer
   - being less feature rich 
   - as far as I am aware **no emulation** of a foreign platform (i.e. arm kernel runnning on x86 host)  
   - 2022 approx 50k lines of code only
   - firecracker designed with goal of fast startup time and safety at the expense of more feature
   - firecracker needs to be given a linux kernel in ELF (x86) or PE (ARM) format
   - consequently no direct bood of disk images via bootloader etc etc, instead the kernel is provided to firecracker process directly

## More info: 
- via https://lwn.net/Articles/775736/ 
- via https://github.com/firecracker-microvm/firecracker

## Issues tackled 
1. instructions how to generate a archlinux that can be run in firecracker via [create.arch.linux.vm.files.md](https://github.com/alexmahr-de/arch.linux.vm.on.firecracker.vm/blob/master/create.arch.linux.vm.files.md)
2. how to start/run the vm (for trial purposes without jailor = nonprod) [run.archlinux.vm.via.firecracker.md]{https://github.com/alexmahr-de/arch.linux.vm.on.firecracker.vm/blob/master/run.archlinux.vm.via.firecracker.md)
