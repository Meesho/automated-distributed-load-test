#!/bin/bash
  
echo "CHANGING NUMBER OF SLAVES TO $1"

asg=$(hostname  -I)

aws autoscaling update-auto-scaling-group --auto-scaling-group-name slaves-$asg --min-size $1 --desired-capacity $1  --max-size $1