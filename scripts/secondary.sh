#!/bin/bash

replSetName=$1
mongoAdminUser=$2
mongoAdminPasswd=$3

disk_format() {
	cd /tmp

	for ((j=1;j<=3;j++))
	do
		wget https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh 
		if [[ -f /tmp/vm-disk-utils-0.1.sh ]]; then
			bash /tmp/vm-disk-utils-0.1.sh -b /var/lib/mongo -s
			if [[ $? -eq 0 ]]; then
				sed -i 's/disk1//' /etc/fstab
				umount /var/lib/mongo/disk1
				mount /dev/md0 /var/lib/mongo
			fi
			break
		else
			echo "download vm-disk-utils-0.1.sh failed. try again."
			continue
		fi
	done
		
}


install_mongo4() {
	
	#create repo
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
	echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list

	apt-get update

	#install
	apt-get install -y mongodb-org

	#configure
	#sed -i 's/\(bindIp\)/#\1/' /etc/mongod.conf
}

install_mongo4
disk_format

#start mongodb
mongod --bind_ip 0.0.0.0 -v --dbpath /var/lib/mongo/ --logpath /var/log/mongodb/mongod.log --fork

sleep 30
ps -ef |grep "mongod" | grep -v grep
n=$(ps -ef |grep "mongod" | grep -v grep |wc -l)
echo "the number of mongod process is: $n"
if [[ $n -eq 1 ]];then
    echo "mongod started successfully"
else
    echo "Error: The number of mongod processes is 2+ or mongod failed to start because of the db path issue!"
fi

#create users
mongo <<EOF
use admin
db.createUser({user:"$mongoAdminUser",pwd:"$mongoAdminPasswd",roles:[{role: "userAdminAnyDatabase", db: "admin" },{role: "readWriteAnyDatabase", db: "admin" },{role: "root", db: "admin" }]})
exit
EOF
if [[ $? -eq 0 ]];then
    echo "mongo user added succeefully."
else
    echo "mongo user added failed!"
fi

#stop mongod
sleep 15
echo "the running mongo process id is below:"
ps -ef |grep mongod | grep -v grep |awk '{print $2}'
MongoPid=`ps -ef |grep mongod | grep -v grep |awk '{print $2}'`
echo "MongoPid is: $MongoPid"
kill -2 $MongoPid

sleep 15
MongoPid1=`ps -ef |grep mongod | grep -v grep |awk '{print $2}'`
if [[ -z $MongoPid1 ]];then
    echo "shutdown mongod successfully"
else
    echo "shutdown mongod failed!"
    kill $MongoPid1
    sleep 15
fi

#Give permissions for mongo folder (move keyFile)
sudo chmod -R 777 /var/lib/mongo

#restart mongod with auth and replica set
# mongod --bind_ip 0.0.0.0 -v --auth --keyFile /var/lib/mongo/keyfile --dbpath /var/lib/mongo/ --replSet $replSetName --logpath /var/log/mongodb/mongod.log --fork

# #check if mongod started or not
# sleep 15
# n=`ps -ef |grep "mongod" |grep -v grep|wc -l`
# if [[ $n -eq 1 ]];then
#     echo "mongo started successfully"
# else
#     echo "mongo started failed!"
# fi
