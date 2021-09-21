#!/bin/bash
LIST=/path/to/*.csv
login="login"
password="password"
request_uri='$request_uri'
while read line
do
DONOR=$(echo ${line} | cut -d\; -f1 | grep / | cut -d/ -f4-)
SPLIT_DOMAIN=$(echo ${line} | cut -d\; -f1 | grep / | cut -d/ -f3 | sed "s/www\./ /" | sed "s/\./_/")
DOMAIN=$(echo ${line} | cut -d\; -f1 | grep / | cut -d/ -f3 | sed "s/www\.//")
#For debug
#echo "domain-"$DOMAIN
#echo "split_domain-"$SPLIT_DOMAIN
ACCEPTOR=$(echo ${line} | cut -d\; -f2)
OUT_FILE_NAME=$(echo $SPLIT_DOMAIN"_redirects.conf")
if [ "${DONOR}" = "" ]; then
echo "if ($request_uri  =  / )  {
          rewrite (.*) ${ACCEPTOR} permanent;
      }" >> $(pwd)/$OUT_FILE_NAME
else
echo "if ($request_uri = "/${DONOR}") {
          rewrite (.*) ${ACCEPTOR} permanent;
      }" >> $(pwd)/$OUT_FILE_NAME
fi
done < ${LIST}
cloudflare_check=$(dig $DOMAIN NS | grep "cloudflare")
if [[ $cloudflare_check ]]; then
        echo "catch"
	echo $DOMAIN
        read  -n 16 -p "Find Clodflare, please insert server ip:" serv_addr
        echo $serv_addr
else 
        echo "empty"
        serv_addr=$DOMAIN
        echo $serv_addr
fi
#For debug 
#echo $DOMAIN"_____"$SPLIT_DOMAIN
sshpass -p $password scp -o "StrictHostKeyChecking no" ./$OUT_FILE_NAME $login@$serv_addr:/tmp/$OUT_FILE_NAME
rm $OUT_FILE_NAME
if sshpass -p $password ssh -to "StrictHostKeyChecking no" $login@$serv_addr "[ -f /etc/nginx/include/$OUT_FILE_NAME ]"; then
        echo "Find old redirect"
        sshpass -p $password ssh -to "StrictHostKeyChecking no" $login@$serv_addr "sudo rm /etc/nginx/include/$OUT_FILE_NAME; sudo mv /tmp/$OUT_FILE_NAME /etc/nginx/include/$OUT_FILE_NAME; sudo /usr/sbin/nginx -t && sudo /etc/init.d/nginx restart"
else
        echo "Without old redirect"
        sshpass -p $password ssh -to "StrictHostKeyChecking no" $login@$serv_addr "sudo mv /tmp/$OUT_FILE_NAME /etc/nginx/include/$OUT_FILE_NAME; sudo sed -i '/server_name/a \    include /etc/nginx/include/$OUT_FILE_NAME\;' " /etc/nginx/sites-available/$DOMAIN.conf"; sudo /usr/sbin/nginx -t && sudo /etc/init.d/nginx restart"
fi
rm -f /path/to/*.csv
