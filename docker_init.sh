#!/bin/bash
# description: docker install and accelerate image 
#

function docker_source(){
	mkdir -pv /etc/docker/ && tee /etc/docker/daemon.json <<-'EOF'
	{ "registry-mirrors":  ["https://6onr63io.mirror.aliyuncs.com",
							  "http://hub-mirror.c.163.com"] }
EOF
	[[ $? -eq 0 ]] && systemctl restart docker.service && echo 'INFO: prepare image accelerate Success!'
}

function install_docker(){
	tee /etc/yum.repos.d/docker-ce.repo <<-'EOF'
		[docker-ce-stable]
		name=Docker CE Stable - $basearch
		baseurl=https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/$releasever/$basearch/stable
		enabled=1
		gpgcheck=1
		gpgkey=https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/gpg
EOF
	yum install -y docker  
	if [[ $? -eq 0  ]]; then
		echo 'docker-ce install finished!'
		systemctl start docker && echo 'INFO: docker-ce start Success!'
		systemctl enable docker
	else
		echo 'ERROR: docker-ce install Failed!' && return 1 
	fi
}

install_docker && docker_source
