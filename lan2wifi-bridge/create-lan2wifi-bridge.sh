#!/bin/bash -
#title          :create-lan2wifi-bridge.sh
#description    :Automation script to set up a raspberrypi as a network bridge
#author         :Tony DeMatteis
#date           :20200824
#version        :0.1
#os             :Based Raspberry Pi OS Lite 32
#usage          :./create-lan2wifi-bridge.sh
#notes          :This will create a non routed bridge across the raspberry pi.
#                The Wifi interface will be set up as an Access Point.
#                Wifi clients connecting to the AP will on same network
#                /broadcast domain as the Pi's LAN interface connected to
#                the upstream network.
#bash_version   :4.4.20(1)-release
#============================================================================

# Ensure the script is run as root or sudo
if [ "$UID" -ne 0 ]
  then echo "Please run as sudo or root"
  exit
fi

# Read in config setup options if file exists
if [[ -f "./lan2wifi.conf" ]]; then
	source ./lan2wifi.conf
fi

# Set config VARS
SSID=${SSID:-Raspi-Wifi}
WPA_PASSPHRASE=${WPA_PASSPHRASE:-...areallycomplicatedpassword...}
COUNTRY_CODE=${COUNTRY_CODE:-US}
CHANNEL=${CHANNEL:-7}
HW_MODE=${HW_MODE:-g}

# Install required packages
apt install -y hostapd

# Set up hostapd permissions and enable
systemctl unmask hostapd
systemctl enable hostapd

# Create a bridge interface
cat <<EOF > /etc/systemd/network/bridge-br0.netdev
[NetDev]
Name=br0
Kind=bridge
EOF

# Create a bridge member config file
cat <<EOF > /etc/systemd/network/br0-member-eth0.network
[Match]
Name=eth0

# TODO - Handled tagged traffic
#Name=eth0.10
#Name=eth0.40

[Network]
Bridge=br0
EOF

# Enable networkd service
systemctl enable systemd-networkd

# Upate DHCPD config to pull IP for bridge interface only.
# This will allow for both the LAN interface to pull IP from dhcp
# and also the WiFi (AP clients) to pull from same DHCP Pool
cat <<EOF >> /etc/dhcpcd.conf
denyinterfaces wlan0 eth0
#denyinterfaces wlan0 eth0 eth0.10 eth0.40
interface br0
EOF

# Ensure WiFi radio is not blocked
rfkill unblock wlan

# Create Access Point config file
# Full config at https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf
cat <<EOF > /etc/hostapd/hostapd.conf
country_code=${COUNTRY_CODE}
interface=wlan0
bridge=br0
ssid=${SSID}
hw_mode=${HW_MODE}
channel=${CHANNEL}
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${WPA_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

echo "Reboot your new bridge.  Both the LAN interface and Wifi Clients connecting the Raspberry Pi AP will pull IPs"
echo "from the same DHCP Address Pool"
echo
echo "Enjoy!"

