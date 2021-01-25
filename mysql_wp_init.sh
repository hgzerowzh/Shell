#!/bin/bash
#

# Root password
user='root'
password='woshiniba'

# Website's path and user's passwd
database='mysite_www'
db_user='hg_www_wp'
db_passwd='woshiniba'
allow_addr=172.18.0.202

set timeout 10

function initMysql() {
	/usr/bin/expect << EOF
	spawn /usr/bin/mysql_secure_installation 
	expect {
		"Enter current password for root (enter for none):" {send "\r";exp_continue}
		"Set root password?" {send "Y\r";exp_continue}
		"New password" {send "$password\r";exp_continue}
		"Re-enter new password" {send "$password\r";exp_continue}       
		"Remove anonymous users?" {send "Y\r";exp_continue}
		"Disallow root login remotely?" {send "n\r";exp_continue}
		"Remove test database and access to it?" {send "Y\r";exp_continue}
		"Reload privilege tables now?" {send "Y\r";exp_continue}
		}
	expect eof
EOF
}

function initDatabase() {
	mysql -u${user} -p${password} -e "create database ${database} character set utf8 collate utf8_bin;"
	mysql -u${user} -p${password} -e "grant all on ${database}.* to "${db_user}"@"${allow_addr}" identified by '${db_passwd}';"
	mysql -u${user} -p${password} -e "flush privileges;"
}

initMysql
initDatabase
