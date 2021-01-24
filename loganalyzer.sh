#!/bin/bash
# Description: Deploying Loganalyzer System in stand-alone CentOS7 System
# Author: Praywu 
# Blog: https://cnblogs.com/hgzero

# MySQL Root Password
user='root'
password='woshiniba'

# Loganalyzer configure 
database='Syslog'
db_user='syslog'
db_passwd='woshiniba'
db_host='127.0.0.1'
allow_addr='127.0.0.1'

# Apache Config 
fqdn='loganalyzer'
website_path='/data/httpd/'

function appInstall(){
	yum install -y $1 &> /dev/null
	systemctl start ${2}.service && systemctl enable ${2}.service &> /dev/null
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m $2 start SUCCESS!" || echo -e "\033[31m[ERROR]\033[0m $2 start FAILED!"
}

function initMysql() {
    {
        yum install -y expect && yum install -y rsyslog-mysql
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
        mysql -u${user} -p${password} < $(rpm -ql "rsyslog-mysql" | grep "createDB")
        mysql -u${user} -p${password} -e "grant all on ${database}.* to "${db_user}"@"${allow_addr}" identified by '${db_passwd}';"
        mysql -u${user} -p${password} -e "flush privileges;"
        sed -i "/mysqld/a innodb-file-per-table=ON" /etc/my.cnf
    } &> /dev/null
    systemctl restart mariadb.service
    [[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m Mariadb initialize Success!" || echo -e "\033[31m[ERROR]\033[0m Mariadb initialize Failed!"
}

function confRsyslog(){
	sed -ri "s@#(.*imudp$)@\1@g" $1
	sed -ri "s@#(.*imtcp$)@\1@g" $1
	sed -ri "s@#(.*Run 514$)@\1@g" $1
	sed -i '/MODULES/a $ModLoad ommysql' $1
	sed -i 's@.*log/messages$@#&@g' $1
	#sed -i 's@.*log/secure$@#&@g' $1
	#sed -i 's@.*log/maillog$@#&@g' $1
	#sed -i 's@.*log/cron$@#&@g' $1
	sed -i "/RULES/a *.info;mail.none;authpriv.none;cron.none  :ommysql:${db_host},Syslog,${db_user},${db_passwd}" $1
	systemctl restart rsyslog.service
    [[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m Rsyslog configure OK." || echo -e "\033[31m[ERROR]\033[0m Rsyslog configure Failed!"
}

function confApache(){
    sed -i "s@^#ServerName.*@ServerName $fqdn@g" $1
    sed -i "s@^Listen.*@#&@g" $1
    sed -i "s@^DocumentRoot.*@#&@g" $1
    mkdir -p /var/log/httpd/$fqdn
    echo "Listen 80
            <VirtualHost *:80>  
                Servername ${fqdn}.hgzerowzh.com
                DocumentRoot /data/httpd/$fqdn 
                <Directory '/data/httpd/$fqdn'>
                    Options FollowSymLinks
                    AllowOverRide None
                    Require all granted
                </Directory>        
                CustomLog '|/usr/sbin/rotatelogs /var/log/httpd/${fqdn}/access_log 10M' combined
            </VirtualHost>" > /etc/httpd/conf.d/${fqdn}.conf
	$(httpd -t) && echo -e "\033[32m[INFO]\033[0m Apache config OK!" || echo -e "\033[31m[INFO]\033[0m Apache config Failed!"
	systemctl restart httpd.service
}

function logerGet(){
	wget -c https://raw.sevencdn.com/hgzerowzh/files/main/loganalyzer-3.4.2.zip -P $1 &> /dev/null
	yum install unzip -y &> /dev/null
	unzip $1/loganalyzer-3.4.2.zip -d $1 &> /dev/null  && rm -rf $1/loganalyzer-3.4.2.zip 
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m loganalyzer decompression Complete." || echo -e "\033[31m[ERROR]\033[0m loganalyzer decompression Failed!"
	mkdir -p $1/$fqdn && cp -r $1/loganalyzer-3.4.2/src/* $1/$fqdn 
	cp -r $1/loganalyzer-3.4.2/contrib/*.sh $1/$fqdn && chmod +x $1/$fqdn/*.sh 
	touch $1/$fqdn/config.php
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m loganalyzer configure changed." || echo -e "\033[31m[ERROR]\033[0m Something Error!" 
	chown -R apache:apache $1/$fqdn
}

function phpInstall(){
	yum install -y php php-cli php-common php-gd php-ldap php-mbstring php-mysql php-pdo php-fpm &> /dev/null
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m PHP install Success!" || echo -e "\033[32m[ERROR]\033[0m PHP install Failed!"
}

function init(){
	appInstall 'mariadb*' 'mariadb' && initMysql && confRsyslog '/etc/rsyslog.conf'
	phpInstall && appInstall 'httpd' 'httpd' 
	[[ $? -eq 0 ]] && logerGet '/data/httpd' && confApache '/etc/httpd/conf/httpd.conf' 
	[[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m $fqdn deploy Success!" && echo -e "\033[32m[INFO]\033[0m Contiune to http://IP/"
}

function clear(){
	systemctl stop mariadb.service
    systemctl stop httpd.service
    rm -rf /var/lib/mysql/*
    sed -i "/innodb-file-per-table/d" /etc/my.cnf
    rm -rf /data/httpd/${fqdn}* /var/log/httpd/${fqdn} /etc/httpd/conf.d/${fqdn}.conf
	sed -ri "s@^#(Listen 80)@\1@g" /etc/httpd/conf/httpd.conf
	sed -ri "s@^#(DocumentRoot.*)@\1@g" /etc/httpd/conf/httpd.conf
  	sed -ri "s@^ServerName.*@#&@g" /etc/httpd/conf/httpd.conf

	sed -ri "s@(.*imudp$)@#&@g" /etc/rsyslog.conf
	sed -ri "s@(.*imtcp$)@#&@g" /etc/rsyslog.conf
	sed -ri "s@(.*Run 514$)@#&@g" /etc/rsyslog.conf
	sed -ri "s@^#(.*log/messages$)@\1@g" /etc/rsyslog.conf
#	sed -ri "s@^#(.*log/secure$)@\1@g" /etc/rsyslog.conf 
#	sed -ri "s@^#(.*log/maillog$)@\1@g" /etc/rsyslog.conf 
#	sed -ri "s@^#(.*log/cron$)@\1@g" /etc/rsyslog.conf 
	sed -i '/$ModLoad ommysql/d' /etc/rsyslog.conf && sed -i '/:ommysql:/d' /etc/rsyslog.conf
	systemctl restart rsyslog.service
    [[ $? -eq 0 ]] && echo -e "\033[32m[INFO]\033[0m clear environment OK." || echo -e "\033[31m[ERROR]\033[0m something unknow happend!"
}

function help(){
	echo "Usage: $0 [ init | clear ]"
	echo -e "Deploying Loganalyzer System in stand-alone CentOS7 System. \n"
}

function main(){
	case $1 in 
	init)		
		init ;;
	clear)
		clear ;;	
	*)
		help ;;
	esac
}

main $1 
