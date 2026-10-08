#!/bin/sh -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <zone_id> <api_token> <domain>" && exit 1
fi

ZONE=$1
TOKEN=$2
DOMAIN=$3

CACHE="/tmp/$DOMAIN"
[ -f "$CACHE" ] && OLD=$(cat "$CACHE")

NEW=$(ip -6 addr list scope global | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
[ -z "$NEW" ] && echo "No new IP found" && exit 1

[ "$OLD" = "$NEW" ] && echo "$(date) $NEW unchanged" && exit 0

ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records?type=AAAA&name=$DOMAIN" -H "Authorization: Bearer $TOKEN" | head -1 | cut -d'"' -f6)
[ -z "$ID" ] && echo "ID not found" && exit 1

STATUS=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/$ID" -H "Authorization: Bearer $TOKEN" -H "Content-Type:application/json" -d '{"type":"AAAA","name":"'"$DOMAIN"'","content":"'"$NEW"'","ttl":1,"proxied":false}' | grep -o '"success":[a-z]*' | cut -d':' -f2)
if [ "$STATUS" = "true" ]; then
    echo "$NEW" > "$CACHE"
    echo "$(date) $NEW updated"
else
    echo "$(date) update failed"
fi
