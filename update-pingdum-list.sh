#!/bin/sh -e

### rootで実行してね
if [ "$EUID" != "0" ]; then
  echo "need root"
  exit 1
fi

### いれものを作成
ipset create -exist pingdom-source-temp hash:ip
ipset flush pingdom-source-temp

### get ip list
tempfile=$(mktemp "/tmp/update-pingdom.tmp.XXXXXX")
curl -f --silent -o ${tempfile} https://my.pingdom.com/probes/ipv4

### ipset add
cat ${tempfile} | while read line
do
  ipset add pingdom-source-temp ${line}
done

### pingdom-source list があれば swap, なければ rename
ipset list pingdom-source > /dev/null 2>&1
if [ $? -eq 0 ]; then
  ipset swap pingdom-source-temp pingdom-source
else
  ipset rename pingdom-source-temp pingdom-source
fi

ipset save > /etc/ipset.conf

rm ${tempfile} ||:
