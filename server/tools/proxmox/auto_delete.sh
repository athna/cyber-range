#!/bin/bash

for i in `seq 800 899`
do
    status=`qm status $i`

    if [ "$status" == "status: running" ]; then
    #if [ "$status" == "status: stopped" ]; then
        ./delete_vm.sh $i
    fi
done
