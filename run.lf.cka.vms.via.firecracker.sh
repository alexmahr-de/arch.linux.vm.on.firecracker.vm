!#/bin/bash
# (C)opyright Alexander Mahr 2022 
# GPLv3 license
# description: Use firecracker "hypervizor: to run ubuntu vm

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
   fail "usage: $SCRIPTNAME <archlinux.vm directory> " 
}

cleanup() {
   test -f vmlinuz-linux && rm vmlinuz-linux
   test -n "{APISOCKET:-}" && test -e "$APISOCKET" && rm "$APISOCKET"
   sudo umount ./mountpoint || true
}

trap cleanup EXIT

VM_OUTPUT_DIR="${1:-}"
VM_RAM_MB="4096"

# we require a output directory 
test -n "$VM_OUTPUT_DIR" || usage "error: no <output directory> provided"

cd "$VM_OUTPUT_DIR"


# get GPLv2 licensed shell script from linux kernel source that gets an uncompressed
# version of the linux kernel binary (i.e. ELF format for x86
test -f extract-vmlinux.sh || {
    wget -O extract-vmlinux.sh \
    https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux
    chmod u+x extract-vmlinux.sh
}

# get APACHE licensed firecracker binary 
test -x '$(which firecracker)' && ln -s "$(which firecracker)" ./firecracker
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

SUBNETPREFIX="${SUBNETPREFIX:-172.16.20}"

# determine the network interface card (NIC) which the tap device should 
# be setup to network address translate with (via iptables masquerade)
NIC="${NIC:-}"
test -z "$NIC" && NIC="$(ip route get 8.8.8.8 | grep 'dev ' | head -n 1 | 
      sed 's/.*\ dev\ //;s/ src\ .*//')"

INDEX=2;


for HOST in cp worker
#for HOST in cp
do 
    INDEX=$(( $INDEX +1))
    (

    ln -fs ../firecracker "$HOST"/
    ln -fs ../extract-vmlinux.sh "$HOST"/
    cd "$HOST"

    # all this is frustrainig uncoherent setup of tap device
    # likely a way here could / should be to used bonding device ... 
    # so that we do not have to keep multiple dhcpd running
    HOSTTEMPDIR="$(mktemp -d ./tmp.XXXXX)"
    # might be better to have the dhcpd files in the current dir
    HOSTTEMPDIR="."
    SUBNET="$SUBNETPREFIX""$INDEX"    
    IPADDRESS="$SUBNETPREFIX""$INDEX"".1"    


    NEXTTAPNAME='tap.'"$HOST" 
    test -d /sys/class/net/"$NEXTTAPNAME" || {
        # create tap device to use network connection of NIC via network address translation 
        sudo ip tuntap add "$NEXTTAPNAME" mode tap
        sudo ip addr add "$IPADDRESS"/24 dev "$NEXTTAPNAME" 
        sudo ip link set "$NEXTTAPNAME" up
        sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
        sudo iptables -t nat -A POSTROUTING -o "$NIC" -j MASQUERADE
        sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        sudo iptables -A FORWARD -i "$NEXTTAPNAME" -o "$NIC" -j ACCEPT
    }
    
    #setup stuff needed for dhcpd
    cat > "$HOSTTEMPDIR"/dhcpd.conf << EOF
option domain-name-servers 8.8.8.8;
option subnet-mask 255.255.255.0;
option routers $IPADDRESS;
subnet $SUBNET.0 netmask 255.255.255.0 {
  range $SUBNET.2 $SUBNET.100;
}
EOF
        
    DHCPD_LEASEFILE="$(realpath "$HOSTTEMPDIR"/dhcpd.leaeses)"
    DHCPD_PIDFILE="$(realpath "$HOSTTEMPDIR"/dhcpd.pid)"
    sudo touch "$DHCPD_PIDFILE"
    sudo touch "$DHCPD_LEASEFILE"
    sudo dhcpd -cf "$HOSTTEMPDIR"/dhcpd.conf \
        -pf "$DHCPD_PIDFILE" -lf "$DHCPD_LEASEFILE" "$NEXTTAPNAME" &

    # with the prefix we now set the filename for the file containing the rootfs for the guest 
    ROOTFS="rootfs.ext4"
    KERNEL="vmlinux.elf"
    INITRD="initrd"
    APISOCKET="api.unix.socket"
    CONFIG="config.json"

    # let us have a mountpoint
    mkdir -p ./mountpoint

    # mount the file
    sudo mount ./"$ROOTFS" ./mountpoint



    sudo cp ./mountpoint/boot/vmlinuz ./vmlinuz-linux
    sudo chown "$(whoami)" vmlinuz-linux
    sudo cp ./mountpoint/boot/initrd.img ./$INITRD
    sudo chown "$(whoami)" "$INITRD"


    # extract the kernel
    ./extract-vmlinux.sh  vmlinuz-linux > ./"$KERNEL"
    rm vmlinuz-linux


    # unmount the archlinux guest ext4 fs
    sudo umount ./mountpoint

    # remove unix-socket if necessary
    test -e "$APISOCKET" && rm "$APISOCKET"

    # run the vm in firecracker unsafely (as it is not using jailer)
    echo "apisocket $APISOCKET"
    (
    rm output;
    mkfifo output
    ./firecracker --api-sock "$APISOCKET" --config-file "$CONFIG" &>output &
    sudo bash -c "cat output | tee output2; 
    kill $(cat "$DHCPD_PIDFILE")
    rm "$DHCPD_PIDFILE"
    rm "$DHCPD_LEASEFILE"
    sudo ip tuntap del "$NEXTTAPNAME" mode tap 
    " &
    ) &
#    cat out &
#    cat err &

)
done


