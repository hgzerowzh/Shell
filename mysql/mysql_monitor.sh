#!/bin/bash
# description: monitor mysql server 
# 如果MySQL端口和进程同时存在，则认为MySQL服务正常

processCheck=$(ps -ef | grep mysql | grep -v grep | wc -l)
portCheck=$(ss -tnl | grep 3306 | wc -l)

if [ $processCheck -ge 2 ] && [ $portCheck -ge 1 ];then
	echo -e "\033[32m[INFO]\033[0m MySQL is Running."
else
	echo -e "\033[31m[Error] MySQL is not Running. \033[0m"
fi

