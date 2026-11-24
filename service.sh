#!/system/bin/sh
# this service later will moved to General Scripts for enabling and disabling tailscaled service when default state is disabled
# wait for boot to complete
while [ "$(getprop sys.boot_completed)" != 1 ]; do
    sleep 1
done
# ensure boot has actually completed & network is ready
sleep 5
# ensure /dev/net/tun exists on legacy Android (e.g. Android 10 only provides /dev/tun by default)
[ -e /dev/net/tun ] || [ ! -e /dev/tun ] || { mkdir -p /dev/net && ln -sf /dev/tun /dev/net/tun; }
# start service
/data/adb/tailscale/scripts/start.sh