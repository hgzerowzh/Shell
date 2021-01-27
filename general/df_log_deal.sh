#!/bin/bash
# description: 解决 df -h 命令输出到文件中时, 某些行中Filesystem字段内容和后面的字段之间内容不在一行的问题
# 思路: 
#		1. 找到所有以数字开头的行的行号
#		2. 按行号进行迭代, 拿到这些行的内容
#		3. 定位到所有以数字开头行的上一行, 将刚刚拿到的内容填充到这些行的末尾
#		4. 删除所有以数字开头的行

## 问题日志格式:
#Filesystem               Size  Used Avail Use% Mounted on
#/dev/mapper/centos-root    
#17G  2.2G   15G  13% /
#devtmpfs                  
#737M     0  737M   0% /dev
#tmpfs                     
#748M     0  748M   0% /dev/shm
#tmpfs                     
#748M  8.6M  739M   2% /run
#tmpfs                     
#748M     0  748M   0% /sys/fs/cgroup
#/dev/sda1               1014M  125M  890M  13% /boot
#tmpfs                    150M     0  150M   0% /run/user/0
#
## 这是正常的内容
#Filesystem               Size  Used Avail Use% Mounted on
#/dev/mapper/centos-root   17G  2.2G   15G  13% /
#devtmpfs                 737M     0  737M   0% /dev
#tmpfs                    748M     0  748M   0% /dev/shm
#tmpfs                    748M  8.6M  739M   2% /run
#tmpfs                    748M     0  748M   0% /sys/fs/cgroup
#/dev/sda1               1014M  125M  890M  13% /boot
#tmpfs                    150M     0  150M   0% /run/user/0


function deal(){	
	for i in $(grep -noE "^[[:digit:]]+" $1);do
		sed -ri "$((${i%:*}-1))s@\$@& $(sed -n "${i%:*}"p $1)@" $1
	done
	sed -ri "/^[[:digit:]]+/d" $1
}
deal $1
