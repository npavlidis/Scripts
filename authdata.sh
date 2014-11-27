#!/bin/bash
# primitive data collector v.1 (run as root)
#

OUTFILE=`mktemp -p /tmp authdata.XXX`
OUTFILE2=`mktemp -p /tmp authdata2.XXX`

for i in $(find /var/log/auth*); do
	grep "Failed password for root" $i | awk '{print $1" "$2","$9","$11}' >> $OUTFILE
	grep "Failed password for invalid" $i | awk '{print $1" "$2","$11","$13}' >> $OUTFILE
	grep -v "Failed password for root" $i | grep -v "Failed password for invalid" | grep "Failed password for" | awk '{print $1" "$2","$9","$11}' >> $OUTFILE
done

wget -q https://raw.githubusercontent.com/titpetric/iso-country-flags-svg-collection/master/ISO-3166-1.txt -O /tmp/ISO-3166-1.txt

for ip in $(cut -d "," -f3 $OUTFILE | sort | uniq | grep -v "::1"); do
	COUNTRYCODE=`whois $ip | grep country | head -1 | awk '{print $2}'`
	if [ -z "$COUNTRYCODE" ]
	then
		COUNTRYCODE=$(curl -s ipinfo.io/$ip | grep country | awk -F '\"' '{print $4}')
		if [ -z "$COUNTRYCODE" ]
		then
			COUNTRYCODE=NULL
			COUNTRYNAME=NULL
			sed -i "s/$ip/$ip,$COUNTRYNAME/g" "$OUTFILE"
		else
			COUNTRYNAME=$(grep $COUNTRYCODE /tmp/ISO-3166-1.txt | cut -d"," -f2 )
			sed -i "s/$ip/$ip,$COUNTRYNAME/g" "$OUTFILE"
		fi
	else
		COUNTRYNAME=$(grep $COUNTRYCODE /tmp/ISO-3166-1.txt | cut -d"," -f2 )
		sed -i "s/$ip/$ip,$COUNTRYNAME/g" "$OUTFILE"
	fi
done

for ip in $(cut -d "," -f3 $OUTFILE | sort | uniq | grep -v "::1"); do
	CITY=$(curl -s ipinfo.io/$ip > $OUTFILE2; cat $OUTFILE2 | grep city | awk -F '\"' '{print $4}')
	if [ "$CITY" = null ]
	then
		COUNTRYCODE=$(cat $OUTFILE2 | grep country | awk -F '\"' '{print $4}')
		CITY=$(grep $COUNTRYCODE /tmp/ISO-3166-1.txt | cut -d"," -f2)
	elif [ -z "$CITY" ]
	then
		COUNTRYCODE=$(cat $OUTFILE2 | grep country | awk -F '\"' '{print $4}')
		if [ -z "$COUNTRYCODE" ]
		then
			COUNTRYCODE=NULL
			CITY=NULL
		else
			CITY=$(grep $COUNTRYCODE /tmp/ISO-3166-1.txt | cut -d"," -f2)
		fi
	fi
	sed -i "s/$ip/$ip,$CITY/g" "$OUTFILE"
done

rm -f /tmp/ISO-3166-1.txt
rm -f $OUTFILE2
mv $OUTFILE /home/npavlidis/Downloads/data.csv
chown npavlidis.npavlidis /home/npavlidis/Downloads/data.csv
