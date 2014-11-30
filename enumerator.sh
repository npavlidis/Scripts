#!/bin/bash
# SMB Enumerator
# need to run as root

[ $# -ne 2 ] && { echo "Usage: $0 output-path target-range"; exit 1; }

OUTPATH=$1
TARGERRANGE=$2
OUTFILE1=`mktemp -p /tmp enumerator1.XXX`
OUTFILE2=`mktemp -p /tmp enumerator2.XXX`

# Find the applicable targets
echo -n -e "Identifying targets..."
nmap -sV -p 139,445 $TARGERRANGE --open -oG $OUTFILE1 > /dev/null 2>&1
echo -e " [ \e[32mDONE \e[39m]"
cut -d " " -f 2 $OUTFILE1 | grep -v Nmap | sort | uniq > $OUTFILE2
TARGETVAL=`wc -l $OUTFILE2 | awk '{print $1}'`

if [ "$TARGETVAL" -eq 0 ]
then
	echo -e "No SMB systems found on that range... "
	echo -e "Exiting... "
else
	# run the scans
	for ip in $(cat $OUTFILE2); do
		echo -n -e "Scanning IP: $ip"
		mkdir -p $OUTPATH/$ip
		nmap -sU -sS --script=smb-check-vulns -p U:137,T:139,T:445 --script-args=unsafe=1 $ip > $OUTPATH/$ip/nmap-smb-vulns.txt 2>&1
		nmap -sU -sS --script=smb-enum-users -p U:137,T:139,T:445 $ip > $OUTPATH/$ip/nmap-smb-enum-users.txt 2>&1
		nmap -sU -sS --script=smb-os-discovery -p U:137,T:139,T:445 $ip > $OUTPATH/$ip/nmap-smb-os-discovery.txt 2>&1
		nbtscan -vh $ip > $OUTPATH/$ip/nbtscan.txt 2>&1
		enum4linux -a $ip > $OUTPATH/$ip/enum4linux.txt 2>&1
		smbclient -N -L $ip > $OUTPATH/$ip/smbclient.txt 2>&1
		echo -e " [ \e[32mDONE \e[39m]"
	done
fi

echo -n -e "Cleaning up..."
rm -f $OUTFILE1
rm -f $OUTFILE2
echo -e " [ \e[32mDONE \e[39m]"
echo -e "SMB Enumeration completed."
