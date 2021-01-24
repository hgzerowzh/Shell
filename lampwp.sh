#!/bin/bash
# Description: Building LAMP environment and deploying WordPress website in stand-alone CentOS7 System
# Author: Praywu 
# Blog: https://cnblogs.com/hgzero

# MySQL Root Password
user='root'
password='woshiniba'

# WordPress Connect MySQL Config 
database='mysite_www'
db_user='hg_www_wp'
db_passwd='woshiniba'
db_host='127.0.0.1'
allow_addr='127.0.0.1'

# Apache Config 
fqdn='www.hgzerowzh.com'
website_path='/data/httpd/'


function phpSource(){
	if $(rpm -qa | grep -q 'webtatic-release' && rpm -qa | grep -q 'epel-release' );then
		echo -e "\033[32m[INFO]\033[0m webtatic source already Installed!" 
	else
		{
			rpm -Uvh https://mirror.webtatic.com/yum/el7/epel-release.rpm
			rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm		
		} &> /dev/null
		echo -e "\033[32m[INFO]\033[0m webtatic source Installed." 
	fi
}

function initMysql() {
	{
		yum install -y expect 
		set timeout 10
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
		mysql -u${user} -p${password} -e "create database ${database} character set utf8 collate utf8_bin;"
		mysql -u${user} -p${password} -e "grant all on ${database}.* to "${db_user}"@"${allow_addr}" identified by '${db_passwd}';"
		mysql -u${user} -p${password} -e "flush privileges;"
		sed -i "2i skip-name-resolve=ON\ninnodb-file-per-table=ON" /etc/my.cnf
	} &> /dev/null
	systemctl restart mariadb.service 
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m Mariadb initialize Success!" || echo -e "\033[31m[ERROR]\033[0m Mariadb initialize Failed!"
}

function appInstall(){
	yum install -y $1 &> /dev/null
	systemctl start ${2}.service && systemctl enable ${2}.service &> /dev/null
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m $2 start SUCCESS!" || echo -e "\033[31m[ERROR]\033[0m $2 start FAILED!"
}

function confApache(){
	sed -i "s@#ServerName.*@ServerName $fqdn@g" $1 
	sed -i "s@^Listen.*@#&@g" $1 
	sed -i "s@^DocumentRoot.*@#&@g" $1 
	mkdir -p /var/log/httpd/$fqdn
	echo "Listen 80
			<VirtualHost *:80>	
				Servername $fqdn 
				DocumentRoot /data/httpd/$fqdn 
				<Directory '/data/httpd/$fqdn'>
					Options FollowSymLinks
					AllowOverRide None
					Require all granted
				</Directory>		
				CustomLog '|/usr/sbin/rotatelogs /var/log/httpd/${fqdn}/access_log 10M' combined
			</VirtualHost>" > /etc/httpd/conf.d/$2 
	$(httpd -t) && echo -e "\033[32m[INFO]\033[0m Apache config OK!" || echo -e "\033[31m[INFO]\033[0m Apache config Failed!"
	systemctl restart httpd.service
}

function wpGet(){
	wget -c https://raw.sevencdn.com/hgzerowzh/files/main/wordpress-5.4.4-zh_CN.tar.gz -P $1 &> /dev/null
	tar xf $1/wordpress-5.4.4-zh_CN.tar.gz -C $1 && rm -rf $1/wordpress-5.4.4-zh_CN.tar.gz  
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m WordPress decompression Complete." || echo -e "\033[31m[ERROR]\033[0m WordPress decompression Failed!"
	cp $1/wordpress/wp-config-sample.php $1/wordpress/wp-config.php
	sed -ri "s@'DB_NAME', '(.*)'@'DB_NAME', '$database'@g" $1/wordpress/wp-config.php
	sed -ri "s@'DB_USER', '(.*)'@'DB_USER', '$db_user'@g" $1/wordpress/wp-config.php
	sed -ri "s@'DB_PASSWORD', '(.*)'@'DB_PASSWORD', '$db_passwd'@g" $1/wordpress/wp-config.php
	sed -ri "s@'DB_HOST', '(.*)'@'DB_HOST', '$db_host'@g" $1/wordpress/wp-config.php
	sed -ri "s@'DB_CHARSET', '(.*)'@'DB_CHARSET', 'utf8'@g" $1/wordpress/wp-config.php
	sed -ri "s@'DB_COLLATE', '(.*)'@'DB_COLLATE', 'utf8_bin'@g" $1/wordpress/wp-config.php
	echo -e "\033[32m[INFO]\033[0m WordPress Config file Changed."
	chown -R apache:apache $1/wordpress 
	mv "${website_path}wordpress" "${website_path}${fqdn}"
}

function phpInstall(){
	yum install -y php72w php72w-cli php72w-common php72w-gd php72w-ldap php72w-mbstring php72w-mysql php72w-pdo php72w-fpm &> /dev/null
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m PHP7 install Success!" || echo -e "\033[32m[ERROR]\033[0m PHP7 install Failed!"
}

function init(){
	appInstall 'mariadb*' 'mariadb' && initMysql   
	phpSource 
	phpInstall && appInstall 'httpd' 'httpd' 
	[[ $? -eq 0 ]] && wpGet '/data/httpd' && confApache '/etc/httpd/conf/httpd.conf' 'mysite.conf' 
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m LAMP environment deploy Success!" && echo -e "\033[32m[INFO]\033[0m Contiune to http://IP"
}

function clear(){
	systemctl stop mariadb.service
	systemctl stop httpd.service
	rm -rf /var/lib/mysql/*
	sed -i "/skip-name-resolve/d" /etc/my.cnf
	sed -i "/innodb-file-per-table/d" /etc/my.cnf
	rm -rf "/data/httpd/" "/var/log/httpd/${fqdn}" "/etc/httpd/conf.d/mysite.conf"
	sed -ri "s@^#(Listen 80)@\1@g" /etc/httpd/conf/httpd.conf
	sed -ri "s@^#(ServerName.*)@\1@g" /etc/httpd/conf/httpd.conf
	sed -ri "s@^#(DocumentRoot.*)@\1@g" /etc/httpd/conf/httpd.conf
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m clear environment Success!" || echo -e "\033[31m[ERROR]\033[0m something unknow happend!"
}

function help(){
	echo "Usage: $0 [ init | clear ]"
	echo -e "Deploying LAMP Environment on CentOS7 System. \n"
}

function main(){
	case $1 in 
	init)		
		init || clear ;;
	clear)
		clear ;;	
	*)
		help ;;
	esac
}

main $1 