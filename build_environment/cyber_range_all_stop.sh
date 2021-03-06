#!/bin/bash
# stop cyber_range environment
# - select delete group number range
#   if select 5 stop 1~5 group's vms

tool_dir=/root/github/cyber_range/server/tools/proxmox # proxmox tool dir
LOG_FILE="./setup.log"

# Get JSON data
json_vm_data=`cat json_files/vm_info.json`
json_scenario_data=`cat json_files/scenario_info.json`
day=`echo $json_scenario_data | jq '.day'`
group_num=`echo $json_scenario_data | jq '.group_num'`
student_per_group=`echo $json_scenario_data | jq '.student_per_group'`
scenario_nums=`echo $json_scenario_data | jq ".days[$((day - 1))].scenario_nums[].scenario_num"`

# TODO: Decide to WEB_NUMS and CLIENT_NUMS setting rules
loop_num=1 # 1から始まる通し番号
for _ in $scenario_nums; do
    for g_num in `seq 1 $group_num`; do
        VYOS_NUMS+=("${g_num}${loop_num}1") # vyos number is **1
        WEB_NUMS+=("${g_num}${loop_num}2")  # web server number is **2
        for i in `seq 3 $((2 + $student_per_group))`; do
            CLIENT_NUMS+=("${g_num}${loop_num}${i}") # client pc number are **3 ~ **9
        done
    done
    let "loop_num=loop_num+1" # increment
done

start_time=`date +%s`

# delete before vms
for num in ${VYOS_NUMS[@]} ${WEB_NUMS[@]} ${CLIENT_NUMS[@]}; do
    qm stop $num # stop vm script
done

end_time=`date +%s`

time=$((end_time - start_time))
echo $time

# output logs
cat << EOL >> $LOG_FILE
[`date "+%Y/%m/%d %H:%M:%S"`] $0 $*
 time              : $time [s]
 group_num         : $group_num
 router_vms:       : ${VYOS_NUMS[@]}
 server_vms:       : ${WEB_NUMS[@]}
 client_vms:       : ${CLIENT_NUMS[@]}

EOL
