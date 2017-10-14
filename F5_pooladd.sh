#!/bin/bash
set -e
Create="tmsh create ltm pool"
Modify="tmsh modify ltm pool"
#set -x
red="\033[31m"
green="\033[32m"
close="\033[0m"
#set +x
#define a pool name;
read -p "Please input your pool name:" poolname
#create a pool and indecate a creations;
$Create $poolname && echo "Createing your poolname,$poolname is created"
#indecating  a monitor is needed;
echo -e "$red Appending a monitor to the pool's memebers,Just make a choice! $close"
cat <<EOF
	The next is the monitor types you can use:
	gateway_icmp|http_head_f5|https_443|inband|ntp|tcp_half_open\
	http|https|https_head_f5|none|tcp|udp
EOF
read -p "Please select a monitor:" monitor_type
#appended a monitor and indecated a success information;	 
$Modify $poolname monitor $monitor_type && echo -e "$green$monitor_type Monitor is successfully added! $close"		
#waiting......
for ((i=1;i<=20;i++)) ; do echo -en "\033[32m*****\033[m";sleep 0.01;  done;echo

echo -e "$red Appending a load-balancing-method for the pool,just make a choice: $close"
cat <<EOF
	The next is the load-balancing-mthod types you can use:(default is round-robin)
	least-connections-member|dynamic-ratio-member|fastest-app-response\
	least-sessions|observed-member|predictive-member|ratio-member
EOF
read -p "Please select a load-balancing-mthod:" lb_method
$Modify $poolname load-balancing-mode  ${lb_method:-round-robin} && echo -e "$green${lb_method:-round-robin} LB_mthod for the $poolname pool is successfully added! $close"
#waiting......
for ((i=1;i<=20;i++)) ; do echo -en "\033[32m*****\033[m";sleep 0.01;  done;echo
#indecated an ip input information;
read -p "Please input your ip range:" Ip1 Ip2
function IpCheck() {
    local ip=$1
    VALID_CHECK=$(echo $ip|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $ip|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ $VALID_CHECK == "yes" ]; then
            return 0
        else
            echo "IP $ip not available!"
            return 1
        fi
    else
        echo "IP format error!"
        return 1
    fi
}
function PortCheck() {
	local port=$1	
	if expr $port + 0 >/dev/null 2>&1 ;then
		if [ $port -gt 0 -a $port -le 65535 ];then
			return 0
		else
			echo "Please input a valid port"
			return 1
		fi
	else
		echo "Please input a numberic port"
		return 1
	fi
	
}
while true;do
	IpCheck $Ip1
	ip1stat=$?
	IpCheck $Ip2
	ip2stat=$?
	[ $ip1stat -eq 0 -a $ip2stat -eq 0 ] && break || read -p "Please input your ip range:" Ip1 Ip2
done

Ip_low=$(echo $Ip1|awk -F . '{print $NF}') 
Ip_high=$(echo $Ip2|awk -F . '{print $NF}')
Prefix=$(echo $Ip1|awk 'BEGIN{FS="."} {print $1FS$2FS$3FS}')
#create a list of IP;
function IpRange() {
	low=$1
	high=$2
	LIP=$(echo $low|awk -F . '{print $NF}')
	HIP=$(echo $high|awk -F . '{print $NF}')
	for i in $(seq $LIP $HIP)
	do
		echo $Prefix$i
	done

} 
#create a list of port;
for ((i=1;i<=20;i++)) ; do echo -en "\033[32m*****\033[m";sleep 0.01;  done;echo 
while true;do
	read -p "Please input your Port range:" LP HP
	PortCheck $LP 
	Lstat=$?
	PortCheck $HP
	Hstat=$?
	[ $Lstat -eq 0 -a $Hstat -eq 0 ] && break || read -p "Please input your Port range:" LP HP
done
function PortRange() {
	LP=$1
	HP=$2
	if [ "$LP" -eq "$HP" ];then
		echo $LP
	else
		for P in $(seq $LP $HP)
		do
			echo $P
		done
	fi
}
IP=$(IpRange $Ip_low $Ip_high)
Port=$(PortRange $LP $HP)
PoolAdd="$Modify $poolname members add"
for ip in $IP
	do
		for port in $Port
			do
				 
				$PoolAdd "{" $ip:$port "}"
			done
	done
#checking the pool status
sleep 5
for ((i=1;i<=20;i++)) ; do echo -en "\033[32m*****\033[m";sleep 0.01;  done;echo
Status="tmsh show ltm pool $poolname"
echo -e "$green$($Status|head -9) $close"

