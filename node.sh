#!/bin/bash

#編輯hosts  才能加入叢集
cat >> /etc/hosts << EOF
172.23.200.227    kubernets-master
172.23.200.229    kubernets-node01
172.23.200.230    kubernets-node02
EOF

#關閉防火牆 / Selinux /swap
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab

#安裝docker
echo '#Docker for centos 7
[docker-ce-stable]
name=Docker CE - Aliyun
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
'>/etc/yum.repos.d/docker-ce.repo

#安裝docker/依賴
yum install -y yum-utils device-mapper-persistent-data lvm2 
yum install -y docker-ce

#重啟docker
systemctl daemon-reload
systemctl enable  docker
systemctl restart  docker


#安裝kubelet kubeadm kubectl
echo '#k8s 
[kubernetes] 
name=Kubernetes 
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64 
enabled=1 
gpgcheck=0 
' >/etc/yum.repos.d/kubernetes.repo

#安裝kubeadm和相關工具
yum -y install kubelet-1.15.5 kubeadm-1.15.5 kubectl-1.15.5 ipvsadm ipset net-tools jq

#啟動kubelet
systemctl daemon-reload
systemctl enable kubelet

#檢查kubeadm，kubelet，kubectl
kubelet --version
kubeadm version -o yaml
kubectl version --short

