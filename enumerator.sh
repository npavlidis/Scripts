#!/bin/bash
# Built to run on Kali Linux
# need to run as root

[ $# -ne 2 ] && { echo "Usage: $0 output-path target-range"; exit 1; }

OUTPATH=$1
TARGERRANGE=$2
OUTFILE1=`mktemp -p /tmp enumerator1.XXX`
OUTFILE2=`mktemp -p /tmp enumerator2.XXX`
MASTERTARGETLIST=`mktemp -p /tmp enumerator3.XXX`
SMBTARGETS=`mktemp -p /tmp enumerator4.XXX`
MSFSNMPRC=`mktemp -p /tmp enumerator5.XXX`
MSFSNMPOUT=`mktemp -p /tmp enumerator5.XXX`
mkdir -p $OUTPATH

# Find targets
echo -e "Starting Scan and Enumeration... grab a beer this is going to take a while..."
sleep 1
echo -n -e "Identifying targets with standard (ARP if local) nmap..."
nmap -sP $TARGERRANGE | grep "report for"  | awk '{print $5}' | sort | uniq > $OUTFILE1 2>&1
echo -e " [ \e[32mDONE \e[39m]"

echo -n -e "Identifying targets with ICMP + TCP nmap..."
nmap -sn --send-ip $TARGERRANGE | grep "report for"  | awk '{print $5}' | sort | uniq > $OUTFILE2 2>&1
echo -e " [ \e[32mDONE \e[39m]"

echo -n -e "Combining results to master target list..."
cat $OUTFILE1 $OUTFILE2 | sort | uniq > $MASTERTARGETLIST
sleep 1
echo -e " [ \e[32mDONE \e[39m]"

echo -e "Starting the scan..."
i=0
for ip in $(cat $MASTERTARGETLIST); do 
	total=`wc -l $MASTERTARGETLIST | awk '{print $1}'`
	echo -n -e "$i / $total systems scanned..." \\r
	mkdir -p $OUTPATH/$ip
	nmap -sS -sV -Pn --top-ports 2000 --open $ip -oN $OUTPATH/$ip/nmap-top2000tcp.txt > /dev/null 2>&1
	nmap -sU -sV -Pn --top-ports 10 --open $ip -oN $OUTPATH/$ip/nmap-top10udp.txt > /dev/null 2>&1
	((i++))
done
echo ""
echo -e " [ \e[32mDONE \e[39m]"

# SMTP Enumeration
echo -n -e "Starting SMTP Enumeration..."
for smtpip in $(grep ^25/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
	nmap --script smtp-enum-users.nse --script smtp-commands.nse --script smtp-open-relay.nse -p 25 $smtpip -oN $OUTPATH/$smtpip/nmap-smtp25.txt > /dev/null 2>&1
done
for smtpip in $(grep ^465/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
        nmap --script smtp-enum-users.nse --script smtp-commands.nse --script smtp-open-relay.nse -p 465 $smtpip -oN $OUTPATH/$smtpip/nmap-smtp465.txt > /dev/null 2>&1
done
for smtpip in $(grep ^587/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
        nmap --script smtp-enum-users.nse --script smtp-commands.nse --script smtp-open-relay.nse -p 587 $smtpip -oN $OUTPATH/$smtpip/nmap-smtp587.txt > /dev/null 2>&1
done    
echo -e " [ \e[32mDONE \e[39m]"

# SNMP Enumeration
echo -n -e "Starting SNMP Enumeration..."
for snmpip in $(grep ^161/udp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
	echo "use auxiliary/scanner/snmp/snmp_login" > $MSFSNMPRC
	echo "set rhosts $snmpip" >> $MSFSNMPRC
	echo "set verbose false" >> $MSFSNMPRC
	echo "run" >> $MSFSNMPRC
	echo "exit" >> $MSFSNMPRC
	msfconsole -n -r $MSFSNMPRC > $MSFSNMPOUT 2>&1
	grep "LOGIN SUCCESSFUL" $MSFSNMPOUT | cut -d ' ' -f4- > $OUTPATH/$snmpip/msf-snmp-community.txt 2>&1
	XITVAL=`echo $?`
	if [ $XITVAL = 0 ]; then
		for community in $(grep "LOGIN SUCCESSFUL" $OUTPATH/$snmpip/msf-snmp-community.txt | cut -d ":" -f 2 | sed 's/^[ \t]*//'); do
			sleep 1
			snmpcheck -c $community -v1 -t $snmpip > $OUTPATH/$snmpip/snmpcheck-$community.txt 2>&1
			grep "Error: No response" $OUTPATH/$snmpip/snmpcheck-$community.txt > /dev/null 2>&1
			XITVAL=`echo $?`
			if [ $XITVAL = 0 ]; then
				sleep 1
				snmpcheck -D -c $community -v2 -t $snmpip > $OUTPATH/$snmpip/snmpcheck-$community.txt 2>&1
			fi
		done
	fi

done
echo -e " [ \e[32mDONE \e[39m]"

# FTP Enumeration
echo -n -e "Starting FTP Enumeration..."
for ftpip in $(grep ^21/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
	nmap --script ftp-anon.nse --script-args ftp-anon.maxlist=-1 -p21 $ftpip -oN $OUTPATH/$ftpip/nmap-ftp.txt > /dev/null 2>&1
done
echo -e " [ \e[32mDONE \e[39m]"

# Finger Enumeration
echo -n -e "Starting Finger Enumeration..."
for fingerip in $(grep ^79/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
	nmap --script finger -p79 $fingerip -oN $OUTPATH/$fingerip/nmap-finger.txt > /dev/null 2>&1
done
echo -e " [ \e[32mDONE \e[39m]"

# NFS Enumeration
echo -n -e "Starting NFS Enumeration..."
for nfsip in $(grep ^111/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
	nmap --script nfs-showmount --script nfs-ls -p111 $nfsip -oN $OUTPATH/$nfsip/nmap-nfs.txt > /dev/null 2>&1
done
echo -e " [ \e[32mDONE \e[39m]"

# SMB Enumeration
echo -n -e "Starting SMB Enumeration..."
grep ^445/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2 > $SMBTARGETS
grep ^139/tcp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2 >> $SMBTARGETS
for smbip in $(sort $SMBTARGETS| uniq); do
	nmap --script smb-check-vulns.nse -p445,139 $smbip -oN $OUTPATH/$smbip/nmap-smb.txt > /dev/null 2>&1
	enum4linux -a -v > $OUTPATH/$smbip/enum4linux.txt 2>&1
done
echo -e " [ \e[32mDONE \e[39m]"

# TFTP Enumeration
echo -n -e "Starting TFTP Enumeration..."
for tftpip in $(grep ^69/udp $OUTPATH/* -R | grep -v filtered | cut -d "/" -f 2); do
	nmap -sU -p 69 --script tftp-enum.nse $tftpip -oN $OUTPATH/$tftpip/nmap-tftp.txt > /dev/null 2>&1
done
echo -e " [ \e[32mDONE \e[39m]"


# HTTP Enumeration
echo -n -e "Starting HTTP Enumeration..."
for httpipport in $(grep http $OUTPATH/* -R | grep -v -i rpc | grep -v -i upnp | grep -v ssl | grep open | awk -F '[/:]' '{print $2":"$4}'); do 
	httpip=`echo $httpipport | cut -d ":" -f1`
	httpport=`echo $httpipport | cut -d ":" -f2`
	cutycapt --url=http://$httpip:$httpport/ --out=$OUTPATH/$httpip/web-port-$httpport.png --out-format=png --javascript=on --java=on
	nmap -p $httpport --script http-headers --script http-methods --script http-title --script http-auth-finder --script http-enum $httpip -oN $OUTPATH/$httpip/web-port-$httpport/nmap-http.txt > /dev/null 2>&1
done
echo -e " [ \e[32mDONE \e[39m]"
# Thats all folks!

echo -n -e "Cleaning up..."
rm -f $OUTFILE1
rm -f $OUTFILE2
rm -f $MASTERTARGETLIST
rm -f $MSFSNMPRC
rm -f $MSFSNMPOUT
echo -e " [ \e[32mDONE \e[39m]"
