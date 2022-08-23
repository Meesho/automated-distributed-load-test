#!/bin/bash

dir=$(pwd)

## Create and clean if exists already
mkdir -p /tmp/datadir && cd /tmp/datadir && rm -r *.*
aws s3 cp s3://<bucket-name>/$1/ ./ --recursive

## Create folders for the entries in the hosts files
while read p; do  mkdir /tmp/datadir/$p; done < $dir/ansible-jmeter-slaves/hosts
len=$(cat $dir/ansible-jmeter-slaves/hosts | wc -l)

for f in *.csv;
do 
    ## Divide and distribute the data to slave folders
    echo "Processing for : $f"
    filelen=$(cat $f | wc -l)
    divfilelen=$(($filelen/$len))
    split -l $divfilelen $f datafilesdistrib_
    filearr=($(ls -l datafilesdistrib_* | awk -F" " '{print $9}' | head -n $len))
    folderarr=($(ls -p | grep /))
    for i in "${!folderarr[@]}"; do mv ${filearr[i]} ${folderarr[i]}/$f ; done
done

## after cleanup
rm datafilesdistrib_*
