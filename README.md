# automated-distributed-load-test
Automate Jmeter distributed load testing setup

Pre-requisites : 
1. Add apache-jmeter and scripts folder inside jmeter folder. All the jmx files are added to the scripts folder.
2. Complete functional setup on AWS with required IAM roles and permissions for creating and destroying EC2 resources and along with adding and fetching objects from S3 buckets.

Steps to configure: 

1. Create an EC2 instance and install ansible and boto3 dependencies on your linux machine.

```
sudo apt-get install python3-pip
pip3 install boto3
sudo apt-get install ansible
```
2. Clone the git repository on the EC2 instance. We are using ‘/home/ubuntu’ as our base directory.
3. Add pem key file used to connect to the servers inside '/opt' folder.
4. Create an AMI using that EC2 instance. This AMI will be used to spin up EC2 instances which will be used as both master and slaves.
5. Create a launch config named ‘perf-jmeter-slaves’ using the AMI.
6. Create an S3 directory which will save the data files. We have used S3 since we have huge data files. So it is not recommended to save it inside the github repository. Create a subfolder inside the S3 bucket based on your scenario.

The setup is now done. 

Steps to run the tests:

1. Push the jmx script inside the ‘scripts’ folder and commit.
2. Create a respective subfolder inside S3 bucket and add required data files inside the folder.
3. Create a Master machine using AMI.You can use this command to launch your instance if you have aws cli setup. 

```
aws ec2 run-instances --image-id <value> --count <value> --instance-type <value> --key-name <value> --security-group-ids <value> --subnet-id <value>
```

4. Login to Master machine and run script 'setup-jmeter-lab.sh' and pass number of slaves, git userid, git password and S3 bucket folder as command line args.

```
#### For 10 slaves
sh setup-jmeter-lab.sh 10 <github_username> <github_pwd> <github-branch-name> <data-folder-name>
```

5. Then change directory to /home/ubuntu/automated-distributed-load-test/jmeter/apache-jmeter-5.4.2/bin and then run the test.

```
nohup sh jmeter.sh -n -t ../../scripts/<filename>.jmx -r -l /home/ubuntu/results/<result-filename>.jtl & 
```
