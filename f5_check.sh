
#!/bin/bash
#Date:20170227
#Author:HuangJianpeng
#Mail:huangjianpeng132@gmail.com
#Description:Script only for bigip ltm checking,
#Used for F5 NetWorks bigip 9.1.1/9.1.2/9.3.0/9.3.7/9.4.5/9.4.8/10.2.3/10.2.4/11.4.1/11.5.4 or later
#set -e
green="\033[32m"
red="\033[31m"
close="\033[0m"
row() {
	for i in $(seq 0 100);do echo -en "${green}-${close}";done;echo
}
#define bigip soft version and hardware types
# bos911="9.1.1";bos930="9.3.0";bos931="9.3.1";bos945="9.4.5";bos948="9.4.8";bos115="11.5.4"
# bhw1500="1500";bhw3400="3400";bhw6400="6400";
# bhw1600="1600";bhw3600="3600";bhw6900="6900";bhw8900="8900"
# bhw2000="2000"

function Tmm_cpu() 
{
	#cpu usage calcuation
	#"((<DeltaTmTotalCycles> - (<DeltaTmIdleCycles> + <DeltaTmSleepCycles>)) / <DeltaTmTotalCycles>) *100"
	h="localhost"
	cmd="snmpwalk -cpublic -v2c"
	sysStatTmTotalCycles=".1.3.6.1.4.1.3375.2.1.1.2.1.41"
	sysStatTmIdleCycles=".1.3.6.1.4.1.3375.2.1.1.2.1.42"
	sysStatTmSleepCycles=".1.3.6.1.4.1.3375.2.1.1.2.1.43"
	tag=$(snmpwalk -cpublic -v2c $h ".1.3.6.1.4.1.3375.2.1.1.2.1.45")
	if [ $? -eq 0 ];then
		total_init=$($cmd $h $sysStatTmTotalCycles|awk '{print $NF}')
		idle_init=$($cmd $h $sysStatTmIdleCycles|awk '{print $NF}')
		slp_init=$($cmd $h sysStatTmSleepCycles|awk '{print $NF}')
		sleep 30s
		total_ter=$($cmd $h $sysStatTmTotalCycles|awk '{print $NF}')
		idle_ter=$($cmd $h $sysStatTmIdleCycles|awk '{print $NF}')
		slp_ter=$($cmd $h sysStatTmSleepCycles|awk '{print $NF}')
	else
		echo -e "\033[31m Something is wrong,$(snmpwalk -cpublic -v2c $h ".1.3.6.1.4.1.3375.2.1.1.2.1") \33[5m"
		exit 100
	fi
	declare -i ds
	declare -i dtt
	declare -i dti
	delta_tm_total=$(($total_ter-$total_init))
	dtt=${delta_tm_total#-}
	delta_tm_idle=$(($idle_ter-$idle_init))
	dti=${delta_tm_idle#-}
	delta_sleep=$(($slp_ter-$slp_init))
	ds=${delta_sleep#-}
	cpu_consum=$(($dtt-$dti-$ds))
	#echo "$dtt"
	cpu_usage=$(echo "$cpu_consum $dtt"|awk '{printf "%.2f",$1/$2*100}')
	echo $cpu_usage
}
function Module_type()
{

	local soft_ver=$(SOFT_VER)
	bos=$(echo $soft_ver|awk '{print $1}')
	
	if [ "$bos" == "9.1.1" ];then
		tp=$(grep -i "BIG-IP LTM" bigip.license | awk  '{print $NF}'|cut -d "|" -f 1)
	elif [ "$bos" == "9.1.2" -o "$bos" == "9.3.1" ];then
		ifcount=`b interface list |grep -v mgmt |grep interface|wc -l`
		cpucount=`cat /proc/cpuinfo |grep  processor|wc -l`
		
		if [ $cpucount -eq 2 -a $ifcount -eq 6 ];then
			tp='1600'

		fi

		if  [ $cpucount -eq 1 -a $ifcount -eq 6 ];then
				#echo "device type:BIGIP 1500"
				tp='1500'
		fi
		if [ $cpucount -eq 1 -a $ifcount -eq 10 ];then
				#echo "device type:BIGIP 3400"
				tp='3400'
		fi
		if [ $cpucount -eq 2 -a $ifcount -eq 10 ];then
				#echo "device type:BIGIP 3600"
				tp='3600'
		fi
		if [ $cpucount -eq 2 -a $ifcount -eq 20 ];then
				#echo "device type:BIGIP 6400"
				tp='6400'
		fi
		if [ $cpucount -eq 4 -a $ifcount -eq 20 ];then
				#echo "device type:BIGIP 6900"
				tp='6900'
		fi
		if [ $cpucount -eq 8 -a $ifcount -eq 26 ];then
				#echo "device type:BIGIP 8900"
				tp='8900'
		fi
	elif [ "$bos" == "11.5.4" ]; then
		tp=$(tmsh show sys hardware field-fmt |grep marketing-name |awk '{print $NF}')
	elif [ "$bos" == "9.4.5" -o "$bos" == "9.4.8" ];then
		tp=$(grep "active module" bigip.license | awk -F "[|]" '{print $1}' |awk '{print $NF}')
	else
		tp=$(grep "active module" bigip.license | awk -F "[|]" '{print $1}' |awk '{print $NF}')
	fi
	echo "$tp"
}

function MEMORY_USAGE()
{
	
	local soft_ver=$(SOFT_VER)
	bos=$(echo $soft_ver|awk '{print $1}')

	big_bos=${bos%.*}


	if [ "$big_bos" == "9.1" -o "$big_bos" == "9.3" ];then
		
		m_total=$(b memory show | grep -i total | awk '{print $3}' | tr -d 'GB')
		
		m_use=$(b memory show | grep -i total | awk '{print $6}' | tr -d "GB|MB")

		m_use_unit=$(b memory show | grep -i total | awk '{print $6}' | tr -d '[:digit:]|.')

		if [ "$m_use_unit" -eq "MB" ];then
			mem_usage=$(echo $m_use $m_total | awk '{print $1/$2/1024*100}')
		elif [ "$m_use_unit" -eq "GB" ];then
			mem_usage=$(echo $m_use $m_total | awk '{print $1/$2*100}')
		else
			echo "The useage memory unit is $m_use_unit"
			exit 1
		fi

	elif [ "$big_bos" == "9.4" ]; then

		m_total=$(b memory show | grep -i tmm | awk '{print $5}' | tr -d 'GB')
		
		m_use=$(b memory show | grep -i tmm | awk '{print $8}' | tr -d "GB|MB")

		m_use_unit=$(b memory show | grep -i tmm | awk '{print $8}' | tr -d '[:digit:]|.')

		if [ "$m_use_unit" == "MB" ];then
			mem_usage=$(echo $m_use $m_total | awk '{print $1/$2/1024*100}')
		elif [ "$m_use_unit" == "GB" ];then
			mem_usage=$(echo $m_use $m_total | awk '{print $1/$2*100}')
		else
			echo "The useage memory unit is $m_use_unit"
			exit 1
		fi

	elif [ "$big_bos" == "10.2" -o "$big_bos" == "11.5" -o "$big_bos" == "11.4" ];then

		m_total=$(tmsh show sys memory  meg | grep "TMM Alloc Memory" | awk '{print $NF}' | tr -d 'G')

		m_use=$(tmsh show sys memory meg | grep "TMM Used Memory" | awk '{print $NF}' | tr -d 'G|M')

		#m_use_unit=$(tmsh show sys memory |grep "TMM Used Memory" | awk '{print $NF}' | tr -d '[:digit:]|.')

		mem_usage=$(echo $m_use $m_total | awk '{print $1/$2*100}')
	else

		echo "The bigip soft version is :$big_bos"
		exit 1
	fi
	
	echo $mem_usage

}
function Throughput()
{
	h="localhost"
	cmd="snmpwalk -cpublic -v2c"
	sysStatClientBytesIn='.1.3.6.1.4.1.3375.2.1.1.2.1.3'
	sysStatClientBytesOut='.1.3.6.1.4.1.3375.2.1.1.2.1.5'
	sysStatServerBytesIn='.1.3.6.1.4.1.3375.2.1.1.2.1.10'
	sysStatServerBytesOut='.1.3.6.1.4.1.3375.2.1.1.2.1.12'
	tag=$(snmpwalk -cpublic -v2c $h ".1.3.6.1.4.1.3375.2.1.1.2.1.45")
	if [ $? -eq 0 ];then
		cli_byte_in1=$($cmd $h $sysStatClientBytesIn|awk '{print $NF}')
		cli_byte_out1=$($cmd $h $sysStatClientBytesOut|awk '{print $NF}')
		ser_byte_in1=$($cmd $h $sysStatServerBytesIn|awk '{print $NF}')
		ser_bype_out1=$($cmd $h $sysStatServerBytesOut|awk '{print $NF}')
		sleep 10s
		cli_byte_in2=$($cmd $h $sysStatClientBytesIn|awk '{print $NF}')
		cli_byte_out2=$($cmd $h $sysStatClientBytesOut|awk '{print $NF}')
		ser_byte_in2=$($cmd $h $sysStatServerBytesIn|awk '{print $NF}')
		ser_byte_out2=$($cmd $h $sysStatServerBytesOut|awk '{print $NF}')

	else
		echo -e "\033[31m Something about SNMP is wrong,$(snmpwalk -cpublic -v2c $h ".1.3.6.1.4.1.3375.2.1.1.2.1") \33[5m"
		exit 50
	fi
	cli_th_byte=$((($cli_byte_in2-$cli_byte_in1)+($cli_byte_out2-$cli_byte_out1)))
	ser_th_byte=$((($ser_byte_in2-$ser_byte_in1)+($ser_byte_out2-$ser_bype_out1)))
	cli_throughput=$( echo "$cli_th_byte"|awk '{printf "%.2f",$1*0.8/1000}')
	ser_throughput=$( echo "$ser_th_byte"|awk '{printf "%.2f",$1*0.8/1000}')
	echo "Client_throughput=$cli_throughput k/s ,Server_throughput=$ser_throughput k/s"
}

function POWER_SUPPLY()
{
	local soft_ver=$(SOFT_VER)
	bos=$(echo $soft_ver|awk '{print $1}')

	big_s_bos=${bos%%.*} #summary software version 9 10 11 12 or 13
	
	local SN=$(DEV_sn)
	#I use the SN's md5  as the value to get  numbers of aciving and installed psu.
	X=$(echo $SN|md5sum|awk '{print $1}')
	#jizhonghesuan_erp and accouting ltm have two psu
	#ems outbound to interface  is a bigip 8900
	#oa system has a bigip 6900
	# 8900	f5-pqus-vmuu
	# 8900	f5-pnqd-fuug
	# 6900	f5-xslk-yvur
	# 6900	f5-mtop-zjpd
	# 6900	f5-kqps-ayze
	# 6900  f5-ijgb-rvbs
	# 3600	f5-xznx-qcgn
	# 3600	f5-ithb-lyon
	# 3600	f5-sxxi-gucx
	# 3600	f5-zkzy-bcnc
	# 2000  f5-rdnh-liqk
	# 2000  f5-fgfk-hfbm
	SN_array=(
	f5-pqus-vmuu
	f5-pnqd-fuug
	f5-xslk-yvur
	f5-mtop-zjpd
	f5-kqps-ayze
	f5-ijgb-rvbs
	f5-xznx-qcgn
	f5-ithb-lyon
	f5-sxxi-gucx
	f5-zkzy-bcnc
	f5-rdnh-liqk
	f5-fgfk-hfbm
	)
	a_len=$((${#SN_array[@]}-1))
	for i in `seq 0 $a_len`
	do
		SN_md5[$i]=$(echo $i|md5sum|awk -F " " '{print $1}')
	done
	#echo ${SN_md5[@]}
	#Tow condictions : single core or dual，default is single mathch=0，if search the SN_md5 in the array of  the known SN_md5 array
	#match is set to 1
	match=0
	for iterm in ${SN_md5[@]}
	do
		if [ "$X" == "$iterm" ];then
			match=1
		fi
	done
	case $match in 
		#I need a software version for using a command which can be used for calculating the  number of psu
		1)
			psu_installed="TWO"
			if [ "$big_s_bos" == "9" -o "$big_s_bos" == "10"]; then
				psu_active=$(b platform show  all|grep -A1 "POWER SUPPLY"|tail -1|awk -F " " '{for(i=1;i<=NF;++i) if($i=="active") ++psu_count}END{print psu_count}')
			elif [ "$big_s_bos" == "11" -o "$big_s_bos" == "12" ]; then
				psu_active=$(tmsh show sys hardware | grep -i "Chassis Power Supply Status" -A 4 | tail -3 | \
				 awk  '{for(i=1;i<=NF;++i) if($i=="up") ++psu_count}END{print psu_count}')
			else
				echo "The bigip soft version is :$big_s_bos"
				exit 1
			fi
			;;
		0)
			psu_installed="ONE"
			#9.3.1 9.1.1 9.4.5 9.4.6 9.4.8  
			if [ "$big_s_bos" == "9" -o "$big_s_bos" == "10" ]; then
				psu_active=$(b platform show  all|grep -A1 "POWER SUPPLY"|tail -1|awk -F " " '{for(i=1;i<=NF;++i) if($i=="active") ++psu_count}END{print psu_count}')
			elif [ "$big_s_bos" == "11" -o "$big_s_bos" == "12" ]; then
				psu_active=$(tmsh show sys hardware | grep -i "Chassis Power Supply Status" -A 4 | tail -3 | \
				 awk  '{for(i=1;i<=NF;++i) if($i=="up") ++psu_count}END{print psu_count}')
			else
				echo "The bigip soft version is :$big_s_bos"
				exit 1
			fi
		;;
	esac	
	echo "$psu_installed,$psu_active"
}
# function CHASSIS_TEMPERATURE()
# {
# 	ch_tmp=$(b platform show all |grep -A 1 "CHASSIS TEMPERATURE"|tail -1|awk '{print $4}')
# 	echo "CHASSIS TEMPERATURE is :$ch_tmp"
# }
function CPU_TEMPERATURE()
{
	local CPU_count=$(cat /proc/cpuinfo |grep -i  "physical id"|sort -u|wc -l)
	local soft_ver=$(SOFT_VER)
	local bos=$(echo $soft_ver|awk '{print $1}')
	local big_bos=${bos%.*}

	if [ "$CPU_count" -eq "1" ]; then
		if [ "$big_bos" == "9.1" -o "$big_bos" == "9.3" ]; then

			cpu_tmp=$(b platform | grep -i cpu |awk '{print $5}' | tr -d '[:alpha:]') #9.3.1 9.1.2 

		elif [ "$big_bos" == "10.2" -o "$big_bos" == "9.4" ]; then
		 	
			cpu_tmp=$(b platform |grep -i temp: |awk '{print $4}' | tr -d '[:alpha:]')  #9.4.7 9.4.6 9.4.8 10.2.4

		elif [ "$big_bos" == "11.4" -o "$big_bos" == "11.5" ]; then

			cpu_tmp=$(tmsh show sys hardware |grep -i "cpu status" -A2 | tail -1 |awk '{print $2}') #11.5.4
		else
			echo "CPU_COUNT is :$CPU_count"
			echo "BIGIP VERSION is: $soft_ver"
			exit 99
		fi

	elif [ "$CPU_count" -eq "2" ]; then
		if [ "$big_bos" == "9.1" -o "$big_bos" == "9.3" ]; then
			cpu_tmp=$(printf "%s/%s\n" $(b platform |grep -i cpu|awk 'gsub("degC","",$0) {print $4}'))
		elif [ "$big_bos" == "11.4" -o "$big_bos" == "11.5" ]; then
			cpu_tmp=$(printf "%s/%s\n" $(tmsh show sys hardware |grep -i "cpu status" -A3 | tail -2 |awk '{print $2}'))
		else
			echo "CPU_COUNT is :$CPU_count"
			echo "BIGIP VERSION is: $soft_ver"
			exit 98
		fi
	else
			echo "CPU_COUNT is :$CPU_count"
			echo "BIGIP VERSION is: $soft_ver"
			exit 97
	fi
	echo "CPU_TEMPERATURE_is:$cpu_tmp"
 }
function UPTIME()
{
	#uptime |awk -F "up|," '{print $2}' | tr -d "[:alpha:]|[:space:]
	ut=$(uptime |awk -F "up|," '{print $2}' | tr -d "[:alpha:]|[:space:]")
	#ut=$(uptime|awk '{printf("%s days\n",$3)}')
	if [ -n "$(echo $ut |grep :)" ]; then

		ut=$(echo $ut|awk -F :  '{print $1}')
		echo "UPTIME_is: $ut hours"
	else
		echo "UPTIME_is: $ut days"
	fi
}
function SYS_date()
{
	echo "Current_date_time is: $(date "+%F %H:%M")"
}
function log_ltm()
{
	cat /var/log/ltm >>/tmp/checking.txt && zcat /var/log/ltm.* >>/tmp/checking.txt
}
function MGMT()
{
	local soft_ver=$(SOFT_VER)

	bos=$(echo $soft_ver|awk '{print $1}')

	big_bos=${bos%.*}

	if [ "$big_bos" == "9.3" -o "$big_bos" == "9.1" ];then

		mgmt_ip=$(b mgmt show |awk '{print $3}') #9.3.1 9.1.1 
	elif [ "$big_bos" == "9.4" ];then

	 	mgmt_ip=$(b mgmt show |awk '{print $2}') #9.4.5 9.4.8 9.4.6 9.4.7
	 elif [ "$big_bos" == "11.5" -o "$big_bos" == "11.4" ];then

		mgmt_ip=$(tmsh list sys management-ip |awk '{print $3}'| awk -F / '{print $1}')
	else
		echo "BIGIP soft version is $bos,this script is not support!"
		exit 99
	fi
	echo "MGMT: $mgmt_ip"
}
function SNMP_agent()

{
	#9.3.1 9.1.1 9.1.2 cant not support snmpd command

	#the allowed snmp manager IP address or network
	Client_Allow_List=$(b snmpd allow show |grep -Ev 'SNMPD|127'|sed 's/ //g')
	echo  "Acess_IP_list=$Client_Allow_List"
	#community config segment
	COMMUNITY_conf=$(b snmpd community all show|grep -v pub|awk '{print $NF}')
	#get community strings
	for j in $COMMUNITY_conf
	do
		COMMUNITY_name=$(b snmpd community "$j" community name show|awk '{print $NF}')
		READ_WRITE_access=$(b snmpd community "$j" access show|awk '{print $NF}')
		ACCESS_oid=$(b snmpd community "$j"  oid show|awk -F "-" '{print $2}')
		SNMP_Manager_ip=$(b snmpd community "$j" source show|awk -F: '{print $NF}')
	
		printf "%s\n" "COMMUNITYR_NAME=$COMMUNITY_name" \
		"ACCESSR_EVEL=$READ_WRITE_access" "SNMP_MANAGER_IP=$SNMP_Manager_ip" "SNMP_OID=$ACCESS_oid"
	done
}

function SNMP_agent_tmsh()
{
	local snmp_command="tmsh list sys snmp"

	#the allowed snmp manager IP address or network
	Client_Allow_List=$($snmp_command allowed-addresses |grep allowed-address | cut -d { -f 2 | tr -d '}')
	tag=$(echo $Client_Allow_List| awk '{print $NF}')
	if [ "$tag" == "none" ] ;then
		echo "No snmp information configured "
		exit 100
	else
		echo  "Acess_IP_list=$Client_Allow_List"
	fi
	#community config segment
	COMMUNITY_conf=$($snmp_command communities |grep community-name  -B 1 |grep { |tr -d {)
	#get community strings
	for j in $COMMUNITY_conf
	do
		COMMUNITY_name=$($snmp_command communities '{' $j '{' community-name '}' '}' | grep community-name | awk '{print $NF}')
		READ_WRITE_access=$($snmp_command communities '{' $j '{' access '}' '}' | grep access | awk '{print $NF}')
		ACCESS_oid=$($snmp_command communities '{' $j '{' oid-subset '}' '}' | grep oid-subset | awk '{print $NF}')
		SNMP_Manager_ip=$($snmp_command communities '{' $j '{' source '}' '}' | grep source | awk '{print $NF}')
	
		printf "%s\n" "COMMUNITYR_NAME=$COMMUNITY_name" \
		"ACCESSR_EVEL=$READ_WRITE_access" "SNMP_MANAGER_IP=$SNMP_Manager_ip" "SNMP_OID=$ACCESS_oid"
	done
}

function SNMP_trap()
{
	#SNMP trap enable or disable information
	SNMP_trap_fun=$(b snmpd agenttrap show|awk '{print $NF}')
	DEV_traps=$(b snmpd bigip traps show|awk '{print $NF}')
	#TRAPs iterms
	TRAP_iterms=$(b snmpd trapsess all show|awk '{print $NF}')
	for i in $TRAP_iterms
	do
		TRAP_ver=$(b snmpd trapsess $i version | awk '{print $NF}')
		TRAP_comm=$(b snmpd trapsess $i community show |awk '{print $NF}')
		TRAP_host=$(b snmpd trapsess $i host show|awk '{print $NF}')
		TRAP_host_port=$(b snmpd trapsess $i port show|awk '{print $NF}')
		echo -e "TRAP_iterm=$i\nTRAP_version=$TRAP_ver\nTRAP_community=$TRAP_comm\nTRAP_host=$TRAP_host\nTRAP_host_port=$TRAP_host_port\n"
	done
	echo -e "TRAP_functions=$SNMP_trap_fun\nBIGIP_traps_function=$DEV_traps\n"
}

function SNMP_trap_tmsh()
{
	local snmp_command="tmsh list sys snmp"
	#SNMP trap enable or disable information and bigip traps

	SNMP_trap_fun=$($snmp_command agent-trap |grep agent-trap | awk '{print $NF}')
	DEV_traps=$($snmp_command bigip-traps | grep bigip-traps | awk '{print $NF}')
	if [ "$SNMP_trap_fun" != "enabled" ] ;then
		echo "Warning snmp traps is not enabled! Checking the config of snmp."
		exit 51
	fi
	#TRAPs iterms
	TRAP_iterms=$($snmp_command traps | grep community -B 1 | grep '{' | tr -d '{| ')

	if [ "TRAP_iterms" == 'none' ] ;then
		echo "Warning snmp traps is not enabled! Checking the config of snmp."
		exit 51
	fi

	for i in $TRAP_iterms
	do
		TRAP_ver=$($snmp_command traps '{' $i '{' version '}' '}' | grep version  | awk '{print $NF}')
		TRAP_comm=$($snmp_command traps '{' $i '{' community '}' '}' | grep community  | awk '{print $NF}')
		TRAP_host=$($snmp_command traps '{' $i '{' host  '}' '}' | grep host | awk '{print $NF}')
		TRAP_host_port=$($snmp_command traps '{' $i '{' port '}' '}' | grep port | awk '{print $NF}')
		echo -e "TRAP_iterm=$i\nTRAP_version=$TRAP_ver\nTRAP_community=$TRAP_comm\nTRAP_host=$TRAP_host\nTRAP_host_port=$TRAP_host_port\n"
	done
	echo -e "TRAP_functions=$SNMP_trap_fun\nBIGIP_traps_function=$DEV_traps\n"
}

function syslog_setting()
{
	remote_host=$(b syslog list all |grep server|awk '{print $NF}')
	if [ $remote_host=="none" ] ;then
		echo "Syslog server is not setting"
	else
		echo "Syslog server is:$remote_host"
	fi	
}
function syslog_setting_tmsh()
{
	local sys_command="tmsh list sys syslog remote-servers"
	sys_rsers=$($sys_command | grep host -B 1 |grep {  | tr -d '{| ')

	if [ -z "$sys_rsers" ] ;then
		echo "Syslog_server_is:none"
	else
		for i in $sys_rsers
		do	
		r_syshost=$($sys_command '{' $i '{' host '}' '}' | grep host | awk '{print $NF}')
		r_sysport=$($sys_command '{' $i '{' remote-port '}' '}' | grep remote-port | awk '{print $NF}')
		echo "Syslog_server_is:$r_syshost":"$r_sysport"
		done
	fi	
}
function DEV_Acc_control()
{
	local http_ip=$(b httpd list all|grep -w "All"|sed 's/"//g'|awk '{print $NF}')
	if [ $http_ip=="All" ];then
		HTTP_all="All ip is allowed to manage by http method."
	else
		HTTP_all="The allowed ip is:$all_ip by http method."
	fi
	
	ssh_ip=$(b sshd list all|grep -wi "All"|sed 's/"//g'|awk '{print $NF}')
	
	if [ $ssh_ip=="ALL" ];then
		SSH_all="All ip is allowed to manage by ssh method."
	else
		SSH_all="The allowed ip is:$ssh_ip by ssh method."
	fi
	
	echo -e "$HTTP_all\n$SSH_all"
}

function DEV_Acc_control_tmsh()
{
	
	httpd_ip=$(tmsh list sys httpd allow |grep allow |grep -i -w All)

	if [ -z "$httpd_ip" ];then
		httpd_ip=$(tmsh list sys httpd allow | tr -d '[:alpha:]|{|}')
	else
		httpd_ip='All'
	fi
	sshd_ip=$(tmsh list sys sshd allow |grep allow |grep -i All -w )
	if [ -z "$sshd_ip" ];then
		sshd_ip=$(tmsh list sys sshd allow | tr -d '[:alpha:]|{|}')
	else
		sshd_ip='All'
	fi

	echo -e "HTTP_all_addr: $(echo $httpd_ip)"
	echo -e "SSH_all_addr: $(echo $sshd_ip)"
}

function NET_failover()
{
	net_fail_state=$(b failover network failover show|awk '{print $NF}')
	if [ $net_fail_state=="disable" ];then
		echo "NETWORK failover is disabled."
	elif [ $net_fail_state=="enable" ];then
		echo "NETWORK failover is enabled."
	else
		echo "NETWORK failover is $net_fail_state"
	fi
}

function NET_failover_tmsh()
{
	net_fail_state=$(tmsh list cm device-group network-failover |grep enable| wc -l)
	if [ $net_fail_state -eq 0 ];then
		echo "NETWORK failover is disabled."
	elif [ $net_fail_state -ge  1 ];then
		echo "NETWORK failover is enabled."
	fi
}

function HA_feature()
{	b ha table all show|grep -E "VLAN|gateway"
	if [ $? -eq 0 ];then
		b ha table all show|grep -E "VLAN|gateway"|awk '{if ($5=="yes") {print $1,$2,$3,"is enabled"} else {print $1,$2,$3,"is disabled"}}'
	else
		echo "Fail safe feature is disabled."
	fi
}

function HA_feature_tmsh()
{	
	vlan_fa=$(tmsh show sys ha-status |grep -i vlan-failsafe|uniq|awk '{print $2}')

	if [ -n "$vlan_fa" ];then
		echo "vlan-failsafe: $vlan_fa"
	else
		echo "Fail-safe feature is disabled."
	fi
}

function ACT_Conn()
{

	h="localhost"
	cmd="snmpwalk -cpublic -v2c"
	sysStatClientCurConns=".1.3.6.1.4.1.3375.2.1.1.2.1.8"
	act_swap=$($cmd $h $sysStatClientCurConns)
	act_conn=${act_swap##F5-BIGIP-SYSTEM-MIB::sysStatClientCurConns.0 = Counter64: }
	echo "Active connestions are:$act_conn"

}
function NEW_conn()
{
	h="localhost"
	cmd="snmpwalk -cpublic -v2c"
	sysTcpStatAccepts=".1.3.6.1.4.1.3375.2.1.1.2.12.6"
	sysStatServerTotConns=".1.3.6.1.4.1.3375.2.1.1.2.1.14"
	
	cli_acc_swap1=$($cmd $h $sysTcpStatAccepts)
	cli_accept1=${cli_acc_swap1##F5-BIGIP-SYSTEM-MIB::sysTcpStatAccepts.0 = Counter64: }
	ser_conn_swap1=$($cmd $h $sysStatServerTotConns)
	ser_conn1=${ser_conn_swap1##F5-BIGIP-SYSTEM-MIB::sysStatServerTotConns.0 = Counter64: }
	sleep 10s
	cli_acc_swap2=$($cmd $h $sysTcpStatAccepts)
	cli_accept2=${cli_acc_swap2##F5-BIGIP-SYSTEM-MIB::sysTcpStatAccepts.0 = Counter64: }
	ser_conn_swap2=$($cmd $h $sysStatServerTotConns)
	ser_conn2=${ser_conn_swap2##F5-BIGIP-SYSTEM-MIB::sysStatServerTotConns.0 = Counter64: }
	
	delta_c_a=$(($cli_accept2-$cli_accept1))
	delta_s_conn=$(($ser_conn2-$ser_conn1))
	echo "$delta_c_a $delta_s_conn" |awk '{printf "ClientSideCon:%.1f\tSerSideCon:%.1f\n",$1/10,$2/10}'
}

# SN judgement
function DEV_sn()
{	
	#get a device soft version
	local soft_ver=$(SOFT_VER)
	bos=$(echo $soft_ver|awk '{print $1}')	
	
	if [ "$bos" == "9.1.1" ];then
		SN=$(grep -i "Appliance SN"  bigip.license|awk '{print $NF}')		
	elif [ "$bos" == "11.5.4" ]; then

		SN=$(tmsh show sys hardware |grep -i "Chassis Serial" |awk '{print $NF}')
	else	

		SN=$(b platform |grep -i -E "(Chassis:|Chassis   serial)" | awk '{print $4}')
	fi

	echo "Device_Serial_Number: $SN"

}
#HOSTNAME
function DEV_hn()
{
	if [ b system hostnameb system hostname >/dev/null 2&>1 ];then
		{HN=$(b system hostname | awk -F: '{print $2}')
		echo "Hostname:$HN"} 
	else
		echo "HOSTNAME: $HOSTNAME"
	fi
}
#dev_IP
function DEV_ip()
{
	local soft_ver=$(SOFT_VER)
	bos=$(echo $soft_ver|awk '{print $1}')	
	
	if [ "$bos" == "11.5.4" ];then

		IP_arr=($(tmsh list net self  address |grep -i address |grep -v 1.1.1. |awk -F "address|/" '{print $2}'))

	else
		IP_arr=($(b self list|grep self|grep -v '1.1.1'|awk '{print $2}'))
	fi

	len_arr=${#IP_arr[@]}
	rand=$(($RANDOM%$len_arr))
	#get a random ip
	dev_ip=${IP_arr[rand]}
	echo "DEVICE_IP: $dev_ip"
}

#bigip software version info

function SOFT_VER()
{
	#OS_VERSION=$(b version|grep  BIG-IP|awk '{print $3,$4}')
	OS_VERSION=$(grep -i version /VERSION |awk '{print $NF}')
	OS_HF=$(grep -i Edition /VERSION |awk '{print $NF}')
	echo "$OS_VERSION $OS_HF"
}
#checking the status of the cluster configsync
function CONF_STAT()
{
	local soft_ver=$(SOFT_VER)

	bos=$(echo $soft_ver|awk '{print $1}')	
	
	if [ "$bos" == "11.5.4" ];then

		code=$(tmsh show cm sync-status field-fmt |grep -i status|tail -1|awk '{print $(NF-1),$NF}')
	else
		code_tmp=$(bigpipe config sync show |grep Status)
		code=${code_tmp:4}
	fi

	echo "$code"

}
#checking the device master or slave status
function DEV_HA_STAT() 

{
	local soft_ver=$(SOFT_VER)

	bos=$(echo $soft_ver|awk '{print $1}')	
	
	if [ "$bos" == "11.5.4" ];then
		 stat_code=$(tmsh show sys failover | awk '{print $2}')
	else
		stat_code=`b failover show | cut -d " " -f 2`
	fi
	
	echo "$stat_code"
}
row
echo "Module_type: $(Module_type)"
row
DEV_sn
row
DEV_hn
row
DEV_ip
row
echo "BIGIP_Version :$(SOFT_VER)"
row
echo "SUPPORT_ENGINEER: Jianpeng Huang"
row
echo "SUPPORT_DATE: $(date +%Y/%m/%d)"
row
echo "LOCATION_of_SUPPORT: XiBianMen"
row
echo -n "Config_sync_status: ";CONF_STAT
row
echo "BIGIP_HA_STAUTS_is: $(DEV_HA_STAT)"
row
echo "TMM_CPU_USAGE: $(Tmm_cpu)"
row
echo "MEMORY_USAGE: $(MEMORY_USAGE)"
row
echo $(Throughput)
row
echo -n "Power_supply_installed,Power_in_active: ";POWER_SUPPLY
#CHASSIS_TEMPERATURE
row
CPU_TEMPERATURE
row
UPTIME
row
SYS_date
row
log_ltm
row
MGMT
row

#using different command get information for different bigip version
soft_ver=$(SOFT_VER)

bos=$(echo $soft_ver|awk '{print $1}')

big_bos=${bos%.*}

if [ "$big_bos" == "9.3" -o "$big_bos" == "9.1" ];then

	row
	echo -e "$red $big_s_bos has no command about snmp.$close"
	row
	syslog_setting
	row
	DEV_Acc_control
	row
	HA_feature
	row
	NET_failover
	row
	NEW_conn
	row
	ACT_Conn
	row

elif [ "$big_bos" == "9.4" ];then
		SNMP_agent
		row
		SNMP_trap
		row
		syslog_setting
		row
		DEV_Acc_control
		row
		HA_feature
		row
		NET_failover
		row
		NEW_conn
		row
		ACT_Conn
		row
	 	
elif [ "$big_bos" == "11.5" -o "$big_bos" == "11.4" ];then

		SNMP_agent_tmsh
		row
		SNMP_trap_tmsh
		row
		syslog_setting_tmsh
		row
		DEV_Acc_control_tmsh
		row
		HA_feature_tmsh
		row
		NET_failover_tmsh
		row
		NEW_conn
		row
		ACT_Conn
		row

else
		echo -e "$red BIGIP soft version is $bos,this script is not support! $close"
		exit 99
fi




