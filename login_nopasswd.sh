#!/bin/bash
# Description: Ansible SSH password free login configuration
# Author: Praywu
# Blog: https://cnblogs.com/hgzero

server=('172.18.0.150' '172.18.0.202')
passwd='woshiniba'
key='/root/.ssh/id_rsa'

function genKey(){
	[ -e "$key" ] || ssh-keygen -t rsa -P "" -f $key 
}

function connServer(){
	/usr/bin/expect << EOF
	spawn /usr/bin/ssh-copy-id -i ${key}.pub root@$1
	expect {
		"want to continue connecting (yes/no)?" {send "yes\r";exp_continue}
		"s password" {send "${passwd}\r";exp_continue}
	}
EOF
}

function exec(){	
	genKey && echo -e "\033[32m[INFO]\033[0m Generate key OK!" || echo -e "\033[31m[ERROR]\033[0m Generate key Failed!" 
	set timeout 15
	for i in $(seq 0 $((${#server[*]}-1)));do
		connServer "${server[$i]}" &> /dev/null
		[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m Get ${server[$i]} Success!" || echo -e "\033[32m[INFO]\033[0m Get ${server[$i]} Failed!"
	done
}

function clear(){
	for i in $(seq 0 $((${#server[*]}-1)));do
		sed -i "/${server[$i]}/d" /root/.ssh/known_hosts
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
