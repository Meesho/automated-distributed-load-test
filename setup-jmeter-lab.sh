#!/bin/bash

asg=$(hostname  -I)
dir=$(pwd)

echo "Creating ASG : slaves-$asg"

#### This will create an ASG with name slaves-$ip.
#### Provide the vpc zone identifier based on your subnet details.
aws autoscaling create-auto-scaling-group --auto-scaling-group-name slaves-$asg --launch-configuration-name <value> --min-size 1 --max-size 1 --vpc-zone-identifier "<value>"

#### This will start the ssh agent if it is in a stopped state.
eval `ssh-agent -s`

#### Add pem key pair file which will help ansible connect to the slave machines.
ssh-add <key.pem>

#### This will set the min,max and desired count for you ASG and spin up slaves accordingly.
sh spinup-slaves.sh $1

sleep 30s

echo "Running ansible script to pull latest repo on slave machines"

#### Get the IP details of newly created machines and save it in hosts file in ansible directory.
sh get-asg-ip.sh | awk -F '"' '{print $2}' > ansible-jmeter-slaves/hosts

#### This will help you split your test data across the slaves so data does not get repeated.
sh test-data-distribute.sh $5

#### For cloning the latest repository changes on the slaves.
cd ansible-jmeter-slaves && ansible-playbook jmeter-slaves.yml -u ubuntu -e "git_user=$2" -e "git_pass=$3" -e "git_branch=$4"

echo "Copying new servers IP into jmeter.properties"

OUT=$(sh $dir/get-asg-ip.sh | awk -F '"' '{print $2}' | awk '{ printf("%s,", $0) }' | rev | cut -c2- | rev)

echo $OUT

sed -i "s/remote_hosts=.*/remote_hosts=$OUT/g" $dir/jmeter/apache-jmeter-5.4.2/bin/jmeter.properties

#### For pulling the latest changes on jmeter master. Add a github URL based on your repository.
cd $dir && git checkout $4 && git pull https://$2:$3@github.com/automated-distributed-load-test.git