#!/bin/sh
# A very basic IPtables / Netfilter script

PATH='/sbin'

# Flush the tables to apply changes
iptables -F

# Default policy to drop 'everything' but our output to internet
iptables -P FORWARD DROP
iptables -P INPUT   DROP
iptables -P OUTPUT  ACCEPT

# Allow established connections (the responses to our outgoing traffic)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow local programs that use loopback (Unix sockets)
iptables -A INPUT -s 127.0.0.0/8 -d 127.0.0.0/8 -i lo -j ACCEPT

# FTP-data connections allow
iptables -A INPUT -p tcp --sport 20 --dport 1024:65535 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Allow incoming traffic on defined ports
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT
#iptables -A INPUT -p tcp --dport 80 -m state --state NEW -j ACCEPT
#iptables -A INPUT -p tcp --dport 4444 -m state --state NEW -j ACCEPT
