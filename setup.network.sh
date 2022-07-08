#!/bin/bash
# license GPLv3
# (c) Copyright 2022 Alexander Mahr Berlin
# description: bash shell script in linux userspace to setup a tap device
#   to be used for making in a firecracker-vm have network access.
#   - the network device can be provided explicitly via setting $NIC 
#     environmental variable. else it is attemped to set 
#   - "tap" referes to linux kernel tuntap devices
#   - to keep the code KISS, no overhead for error tolerance is implemeted 
#     the code may fail (so calling scripts are adviced to check the exit code)
#   - tap devices created are named tapXXX with XXX being a ascending number 
#     each new device being a number incremented by 1 of the largest already
#     existing /sys/class/net/tapXXX device already existing
#   - a cap is done at max 255 devices given that the XXX number is used for
#     defining a subset $SUBNETPREFIX
#   - upon success the script outputs XXX to stdout so other calling code
#     can determine the name of the tap and the network configuration

set -euxo pipefail 

# use /sys to determine already existing tap devices, allowing consecutive 
# numbering
TAPCOUNT="$(sudo ls -1 /sys/class/net/ | grep -e '^tap[0-9][0-9][0-9]$' | 
    sort -n | tail -c 4 || echo 000)"
# output for 
echo "info there are already $TAPCOUNT tap interfaces" >&2;

NEXTTAP="$(( $TAPCOUNT + 1))"
NEXTTAPNAME="tap$(printf '%03d' "$NEXTTAP")"
SUBNETPREFIX="${SUBNETPREFIX:-172.16.}"

# determine the network interface card (NIC) which the tap device should 
# be setup to network address translate with (via iptables masquerade)
NIC="${NIC:-}"
test -z "$NIC" && NIC="$(ip route get 8.8.8.8 | grep 'dev ' | head -n 1 | 
      sed 's/.*\ dev\ //;s/ src\ .*//')"

# create tap device to use network connection of NIC via network address translation 
sudo ip tuntap add "$NEXTTAPNAME" mode tap
sudo ip addr add "$SUBNETPREFIX""$NEXTTAP".1/24 dev "$NEXTTAPNAME" 
sudo ip link set "$NEXTTAPNAME" up
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -t nat -A POSTROUTING -o "$NIC" -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i "$NEXTTAPNAME" -o "$NIC" -j ACCEPT

echo "$NEXTTAP"



