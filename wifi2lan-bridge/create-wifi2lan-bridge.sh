#!/bin/bash -
#title          :create-wifi2lan-bridge.sh
#description    :Automation script to set up a raspberrypi as a network bridge
#author         :Tony DeMatteis
#date           :20200824
#version        :0.1
#os             :Based Raspberry Pi OS Lite 32
#usage          :./create-wifi2lan-bridge.sh
#notes          :This will create a non routed bridge across the raspberry pi.
#                The Wifi connection to an AP will share it's network access
#                with the LAN interface.  The Rasp Pi's IP will reside on the
#                bridge interface.  DHCP will transparently pass across the 
#                Rasp Pi from the LAN interface to the AP CLients.
#bash_version   :4.4.20(1)-release
#============================================================================

# Ensure running as root or sudo
if [ "$UID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Read in config setup options if file exists
if [[ -f "./wifi2lan.conf" ]]; then
	source ./wifi2lan.conf
fi

# Set up internal VARs
IP_ADDRESS_RANGE=${IP_ADDRESS_RANGE:-192.168.4.1/24}
IP_ADDRESS_NETMASK=${IP_ADDRESS_NETMASK:-255.255.255.0}
IP_ADDRESS_GATEWAY=${IP_ADDRESS_GATEWAY:-192.168.4.1}
IP_ADDRESS_RANGE_DHCP_START_OFFERS=${IP_ADDRESS_RANGE_DHCP_START_OFFERS:-192.168.4.11}
IP_ADDRESS_RANGE_DHCP_END_OFFERS=${IP_ADDRESS_RANGE_DHCP_END_OFFERS:-192.168.4.254}
LEASE_TIME=${LEASE_TIME:-12h}
DNS_SERVER=${DNS_SERVER:-1.1.1.1}

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
listen-address=$IP_ADDRESS_GATEWAY   # Specify the address to listen on  
bind-interfaces      # Bind to the interface
server=$DNS_SERVER       # Use Google DNS  
domain-needed        # Don't forward short names  
bogus-priv           # Drop the non-routed address spaces.
dhcp-range=${IP_ADDRESS_RANGE_DHCP_START_OFFERS},${IP_ADDRESS_RANGE_DHCP_END_OFFERS},${IP_ADDRESS_NETMASK},${LEASE_TIME}
EOF

# Enable forwarding
sed -i 's/#net.ipv4.ip_forward\=1/net.ipv4.ip_forward\=1/g' /etc/sysctl.conf

# Add NAT Rule to rc.local to ensure traffic routing from Wifi to Eth
sed -i "s/exit 0/iptables -t nat -A  POSTROUTING -o wlan0 -j MASQUERADE\niptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT\niptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT\nexit 0/g" /etc/rc.local

echo "Reboot your new bridge.  Add a route to your router to point dest ${IP_ADDRESS_RANGE} to the Wifi IP Address."
echo "All traffic will now NAT from the LAN interface.  With the new route on the router, you can reach any device"
echo "( or devices should you decide to connect a switch to the LAN interface ) via the ${IP_ADDRESS_RANGE} network"
echo 
echo "Enjoy!"
