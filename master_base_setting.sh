#!/bin/bash

#-------版本设置-------------
k8s_version=v1.14.6
K8S_VERSION=1.14.6
pause_version=3.1
etcd_version=3.3.10
coredns_version=1.3.1

registry_name='reg.feidee.org/library'
registry_host=reg.feidee.org
reg_host=reg.feidee.org
/usr/bin/which dig
if [ $? = "1" ];then
yum install bind-utils -y
fi

if [ "`/bin/dig  ${registry_host} +short`" = "" ];then
echo "请先把解析镜像私有仓库${registry_host}域名"
exit 1
else
echo "镜像私有仓库域名解析正常"
fi


#---------------------------

function system_setting(){
#导入ipvs模块
ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4"
for kernel_module in ${ipvs_modules}; do
    /sbin/modinfo -F filename ${kernel_module} 
    if [ $? -eq 0 ]; then
        /sbin/modprobe ${kernel_module}
    fi
done

cat << 'EOF' >> /etc/rc.d/rc.local
ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4"
for kernel_module in ${ipvs_modules}; do
    /sbin/modinfo -F filename ${kernel_module} 
    if [ $? -eq 0 ]; then
        /sbin/modprobe ${kernel_module}
    fi
done
EOF


#增加内核参数
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# 禁用fstab中的swap项目
swapoff -a
sed -i '/centos-swap/s/^/#/' /etc/fstab


}

function install_pkg(){

yum clean all 
yum makecache
yum -y install vim  net-tools make gcc gcc-c++ ipvsadm  socat wget rsync openssh-clients yum-utils 
yum -y install docker-ce-cli-18.09.0-3.el7 docker-ce-18.09.3-3.el7 containerd.io-1.2.4-3.1.el7
sed -i "s/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd --insecure-registry $registry_host --insecure-registry $reg_host /" /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl enable docker
systemctl restart docker

yum install -y  kubelet-${K8S_VERSION}-0.x86_64
yum install -y  kubectl-${K8S_VERSION}-0.x86_64  kubeadm-${K8S_VERSION}-0.x86_64
yum install -y  lxcfs-2.0.5-3.el7.centos

systemctl daemon-reload
systemctl enable   kubelet
systemctl restart kubelet

}
#######registry server#######
function pull_images(){
	echo "Pulling Images"
		docker pull mirrorgooglecontainers/kube-apiserver:$k8s_version
		docker pull mirrorgooglecontainers/kube-controller-manager:$k8s_version
		docker pull mirrorgooglecontainers/kube-scheduler:$k8s_version
		docker pull mirrorgooglecontainers/kube-proxy:$k8s_version
		docker pull mirrorgooglecontainers/pause:$pause_version
		docker pull mirrorgooglecontainers/etcd:$etcd_version
		docker pull coredns/coredns:$coredns_version
}

function set_tags(){
	echo "Setting Tags"
		docker tag mirrorgooglecontainers/kube-apiserver:$k8s_version $registry_name/kube-apiserver:$k8s_version
		docker tag mirrorgooglecontainers/kube-controller-manager:$k8s_version $registry_name/kube-controller-manager:$k8s_version
		docker tag mirrorgooglecontainers/kube-scheduler:$k8s_version $registry_name/kube-scheduler:$k8s_version
		docker tag mirrorgooglecontainers/kube-proxy:$k8s_version $registry_name/kube-proxy:$k8s_version
		docker tag mirrorgooglecontainers/pause:$pause_version $registry_name/pause:$pause_version
		docker tag mirrorgooglecontainers/etcd:$etcd_version $registry_name/etcd:$etcd_version
		docker tag coredns/coredns:$coredns_version $registry_name/coredns:$coredns_version
}

function push_images(){
	echo "Pushing Images"
        #sudo docker login -u $username -p $password $registry_host
		docker push $registry_name/kube-apiserver:$k8s_version
		docker push $registry_name/kube-controller-manager:$k8s_version
		docker push $registry_name/kube-scheduler:$k8s_version
		docker push $registry_name/kube-proxy:$k8s_version
		docker push $registry_name/pause:$pause_version
		docker push $registry_name/etcd:$etcd_version
		docker push $registry_name/coredns:$coredns_version
}

########client##############

function local_pull_images(){
	        docker pull $registry_name/kube-apiserver:$k8s_version 
		docker pull $registry_name/kube-controller-manager:$k8s_version 
		docker pull $registry_name/kube-scheduler:$k8s_version 
		docker pull $registry_name/kube-proxy:$k8s_version 
		docker pull $registry_name/pause:$pause_version 
		docker pull $registry_name/etcd:$etcd_version 
		docker pull $registry_name/coredns:$coredns_version 
}

function reset_tags(){
	        docker tag $registry_name/kube-apiserver:$k8s_version k8s.gcr.io/kube-apiserver:$k8s_version
		docker tag $registry_name/kube-controller-manager:$k8s_version k8s.gcr.io/kube-controller-manager:$k8s_version
		docker tag $registry_name/kube-scheduler:$k8s_version k8s.gcr.io/kube-scheduler:$k8s_version 
		docker tag $registry_name/kube-proxy:$k8s_version k8s.gcr.io/kube-proxy:$k8s_version 
		docker tag $registry_name/pause:$pause_version k8s.gcr.io/pause:$pause_version 
		docker tag $registry_name/etcd:$etcd_version k8s.gcr.io/etcd:$etcd_version 
		docker tag $registry_name/coredns:$coredns_version k8s.gcr.io/coredns:$coredns_version
}

main(){
#-------server--------
#pull_images
#set_tags
#push_images
#------client--------
system_setting
install_pkg
local_pull_images
reset_tags
}
main
