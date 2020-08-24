#!/bin/bash -
#title          :create-wifi2lan-bridge.sh
#description    :Automation script to set up a raspberrypi as a network bridge
#author         :Tony DeMatteis
#date           :20200824
#version        :0.1
#os             :Based Raspberry Pi OS Lite 32
#usage          :./create-wifi2lan-bridge.sh
#notes          :This will create a routed bridge across the raspberry pi.
#                The Wifi connection to an AP will share it's network access
#                with the LAN interface.  The LAN interface will offer DHCP.
#bash_version   :4.4.20(1)-release
#============================================================================

# Ensure running as root or sudo
if [ "$UID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Read in config setup options
source ./wifi2lan.conf

# Set up internal VARs
IP_ADDRESS_RANGE=${IP_ADDRESS_RANGE:-192.168.4.1/24}
IP_ADDRESS_NETMASK=${IP_ADDRESS_NETMASK:-255.255.255.0}
IP_ADDRESS_RANGE_DHCP_START_OFFERS=${IP_ADDRESS_RANGE_DHCP_START_OFFERS:-192.168.4.11}
IP_ADDRESS_RANGE_DHCP_END_OFFERS=${IP_ADDRESS_RANGE_DHCP_END_OFFERS:-192.168.4.254}
LEASE_TIME=${LEASE_TIME:-12h}

# Update DHCP config to offer IP Addr on Eth0
cat <<EOF >> /etc/dhcpcd.conf
interface eth0
static ip_address=${IP_ADDRESS_RANGE}
EOF

# Update dnsmasq config
apt install dnsmasq -y
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

sudo cat <<EOF > /etc/dnsmasq.conf
interface=eth0
dhcp-range=${IP_ADDRESS_RANGE_DHCP_START_OFFERS},${IP_ADDRESS_RANGE_DHCP_END_OFFERS},${IP_ADDRESS_NETMASK},${LEASE_TIME}
EOF

# Enable forwarding
sed -i 's/#net.ipv4.ip_forward\=1/net.ipv4.ip_forward\=1/g' /etc/sysctl.conf

# Add NAT Rule to rc.local to ensure traffic routing from Wifi to Eth
sed -i "s/exit 0/iptables -t nat -A  POSTROUTING -o wlan0 -j MASQUERADE\n\nexit 0/g" /etc/rc.local

echo "Reboot your new bridge.  Add a route to your router to point dest ${IP_ADDRESS_RANGE} to the Wifi IP Address."
echo "All traffic will now NAT from the LAN interface.  With the new route on the router, you can reach any device"
echo "( or devices should you decide to connect a switch to the LAN interface ) via the ${IP_ADDRESS_RANGE} network"
echo 
echo "Enjoy!"
