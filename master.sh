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

#配置kubeadm
cat >kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.15.5
clusterName: kubernetes
imageRepository: registry.aliyuncs.com/google_containers
networking:
  serviceSubnet: "10.96.0.0/16"
  podSubnet: "10.100.0.0/16"
  dnsDomain: "cluster.local"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
featureGates:
  SupportIPVSProxyMode: true
mode: ipvs
EOF


#發布配置文件
#使用sftp等方式上傳kube-flannel.yml，kubernetes-dashboard.yaml到用戶根目錄

#部署kubeadm
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee /tmp/kubeadm-init.log
# 保存 join token
egrep 'kubeadm.*join|discovery-token-ca-cert-hash' /tmp/kubeadm-init.log >$HOME/k8s.add.node.txt

#kubectl認證
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p $HOME/.kube
ln -fs /etc/kubernetes/admin.conf $HOME/.kube/config

#讓master也運行pod
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/master=:PreferNoSchedule

#署法蘭網
#複製文件kube-flannel.yml到$HOME
kubectl apply -f kube-flannel.yml

#部署儀表板
#複製文件kubernetes-dashboard.yaml到$HOME
kubectl apply -f kubernetes-dashboard.yaml

#創建訪問用戶和授權
# 把serviceaccount绑定在clusteradmin，授权serviceaccount用户具有整个集群的访问管理权限
kubectl create serviceaccount dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
# 查看访问Dashboard的认证令牌
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}') | awk '/token:/{print$2}' >$HOME/k8s.token.dashboard.txt

#最後
# dashboard 登录令牌如下
cat $HOME/k8s.token.dashboard.txt
# 添加 Node 命令
cat $HOME/k8s.add.node.txt
# 查看 K8S 状态
kubectl get cs
# 查看 Node
kubectl get nodes
# 查看 Pod
kubectl get pod -A
# 查看 dashboard 地址
Local_IP=$(kubectl -n kube-system get cm kubeadm-config -oyaml | awk '/advertiseAddress/{print $NF}')
echo "  https://${Local_IP}:30000"

