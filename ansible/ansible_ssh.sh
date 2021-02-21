#!/bin/bash
# Description: SSH password free login configuration.
# Author: Praywu
# Blog: https://cnblogs.com/hgzero

server='172.18.0.150 172.18.0.202'
passwd='woshiniba'
key='/root/.ssh/id_rsa'

function genKey(){
	[ -e "$key" ] || ssh-keygen -t rsa -P "" -f $key 
}

function connServer(){
	/usr/bin/expect << EOF
	spawn /usr/bin/ssh-copy-id -i ${key}.pub root@$1
	expect {
		"continue connecting" {send "yes\r";exp_continue}
		"password" {send "${passwd}\r";exp_continue}
	}
EOF
}

function exec(){	
	genKey && echo -e "\033[32m[INFO]\033[0m Generate key OK!" || echo -e "\033[31m[ERROR]\033[0m Generate key Failed!" 
	set timeout 15
	for i in $server;do
        connServer $i &>> ansible_ssh.log 
    done
}

function clear(){
	for i in $server;do
        sed -i "/${i}/d" /root/.ssh/known_hosts
    done
}

function help(){
    echo "Usage: $0 [ exec | clear ]"
    echo -e "Ansible SSH password free login configuration \n"
}

function main(){
	case $1 in 
		exec)
			exec;;
		clear)
			clear;;
		*)
			help;;	
	esac
}

main $1