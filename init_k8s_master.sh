#/bin/bash

function check_parm()
{
  if [ "${2}" == "" ]; then
    echo -n "${1}"
    return 1
  else
    return 0
  fi
}

if [ -f ./cluster-info ]; then
	source ./cluster-info 
fi

check_parm "Enter the IP address of master-01: " ${CP0_IP} 
if [ $? -eq 1 ]; then
	read CP0_IP
fi
check_parm "Enter the IP address of master-02: " ${CP1_IP}
if [ $? -eq 1 ]; then
	read CP1_IP
fi
check_parm "Enter the IP address of master-03: " ${CP2_IP}
if [ $? -eq 1 ]; then
	read CP2_IP
fi
check_parm "API_SERVER_NAME: " ${API_SERVER_NAME}
if [ $? -eq 1 ]; then
	read API_SERVER_NAME
fi
check_parm "Enter the Net Interface: " ${NET_IF}
if [ $? -eq 1 ]; then
	read NET_IF
fi
check_parm "Enter the cluster CIDR: " ${CIDR}
if [ $? -eq 1 ]; then
	read CIDR
fi
check_parm "Enter the cluster REGISTYR: " ${REGISTYR}
if [ $? -eq 1 ]; then
	read REGISTYR
fi

echo """
cluster-info:
  master-01:        ${CP0_IP}
  master-02:        ${CP1_IP}
  master-02:        ${CP2_IP}
  k8sapi域名:       ${API_SERVER_NAME}#k8sapi域名,线上部署首先需要把这个域名解析成master-01 IP,这里即为10.201.3.221
  机器主网卡名称:   ${NET_IF}
  k8s内网网段:      ${CIDR}
  私有仓库域名:      ${REGISTYR}
  注意!!!
  1.确定以上信息正确.
  2.确保k8sapi域名和私有仓库域名正常解析.
  3.确保是以root用户在master-01上面执行这个脚本,且所有节点的osadmin账号拥有sudo权限.
"""
echo -n 'Please print "yes" to continue or "no" to cancel: '
read AGREE
while [ "${AGREE}" != "yes" ]; do
	if [ "${AGREE}" == "no" ]; then
		exit 0;
	else
		echo -n 'Please print "yes" to continue or "no" to cancel: '
		read AGREE
	fi
done
/usr/bin/which dig >/dev/null 2>&1 
if [ $? = "1" ];then
yum install bind-utils -y
fi

if [ "`dig  ${API_SERVER_NAME} +short`" != "${CP0_IP}" ];then
echo "请先把k8sapi域名解析到master-01 IP上面"
exit 1
else
echo "k8sapi域名解析正常"
fi

registry_name='reg.feidee.org/library'
registry_host='reg.feidee.org'


if [ "`/bin/dig  ${registry_host} +short`" = "" ];then
echo "请先解析镜像私有仓库${registry_host}域名"
exit 1
else
echo "镜像私有仓库域名解析正常"
fi


mkdir -p ~/ikube/tls
sed -i "s/reg_host=reg.feidee.org/reg_host=${REGISTYR}/g" master_base_setting.sh
sed -i "s/reg_host=reg.feidee.org/reg_host=${REGISTYR}/g" node_base_setting.sh

sed \
-e "s/K8SHA_IP1/${CP0_IP}/g" \
-e "s/K8SHA_IP2/${CP1_IP}/g" \
-e "s/K8SHA_IP3/${CP2_IP}/g" \
nginx-lb/nginx-lb.conf.tpl > nginx-lb/nginx-lb.conf

ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP})

for index in 0 1 2; do
  ip=${IPS[${index}]}
  ssh-copy-id osadmin@${ip}
done


for index in 0 1 2; do
  ip=${IPS[${index}]}
  scp master_base_setting.sh  osadmin@${ip}:/tmp/
  ssh osadmin@${ip} "
    /bin/sudo /bin/mv -f /tmp/master_base_setting.sh /usr/local/src/ && cd /usr/local/src/ && /bin/sudo /bin/bash master_base_setting.sh"
done

for index in 0 1 2; do
  ip=${IPS[${index}]}
  rsync -azvh --delete nginx-lb osadmin@${ip}:/tmp/
  ssh osadmin@${ip} "
    /bin/sudo /bin/mv -f  /tmp/nginx-lb /usr/local/
    /bin/sudo /usr/local/nginx-lb/docker-compose -f  /usr/local/nginx-lb/docker-compose.yaml  up -d"
done

sleep 5
echo """
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.13.4
controlPlaneEndpoint: "${API_SERVER_NAME}:16443"
apiServer:
  certSANs:
  - ${CP0_IP}
  - ${CP1_IP}
  - ${CP2_IP}
  - ${API_SERVER_NAME}
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: ${CIDR}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
""" > /etc/kubernetes/kubeadm-config.yaml

kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf ${HOME}/.kube/config


kubectl apply -f calico/rbac.yaml
cat calico/calico.yaml | sed "s!8.8.8.8!${CP0_IP}!g" | sed "s!10.244.0.0/16!${CIDR}!g" |sed "s!quay.io/calico!${registry_name}!g"| kubectl apply -f -

JOIN_CMD=`kubeadm token create --print-join-command`

for index in 1 2; do
  ip=${IPS[${index}]}
  ssh osadmin@$ip "/bin/sudo mkdir -p /etc/kubernetes/pki/etcd; /bin/sudo mkdir -p /root/.kube/ ;/bin/sudo rm -rf  /root/.kube/config;/bin/sudo chmod 777 -R  /etc/kubernetes"
  scp /etc/kubernetes/pki/ca.crt osadmin@$ip:/etc/kubernetes/pki/ca.crt
  scp /etc/kubernetes/pki/ca.key osadmin@$ip:/etc/kubernetes/pki/ca.key
  scp /etc/kubernetes/pki/sa.key osadmin@$ip:/etc/kubernetes/pki/sa.key
  scp /etc/kubernetes/pki/sa.pub osadmin@$ip:/etc/kubernetes/pki/sa.pub
  scp /etc/kubernetes/pki/front-proxy-ca.crt osadmin@$ip:/etc/kubernetes/pki/front-proxy-ca.crt
  scp /etc/kubernetes/pki/front-proxy-ca.key osadmin@$ip:/etc/kubernetes/pki/front-proxy-ca.key
  scp /etc/kubernetes/pki/etcd/ca.crt osadmin@$ip:/etc/kubernetes/pki/etcd/ca.crt
  scp /etc/kubernetes/pki/etcd/ca.key osadmin@$ip:/etc/kubernetes/pki/etcd/ca.key
  scp /etc/kubernetes/admin.conf osadmin@$ip:/etc/kubernetes/admin.conf
  #ssh osadmin@$ip "sudo sed -i 's/${CP0_IP}/${ip}/' /etc/kubernetes/admin.conf"
  ssh osadmin@$ip "/bin/sudo cp /etc/kubernetes/admin.conf /root/.kube/config"
  ssh osadmin@${ip} "/bin/sudo ${JOIN_CMD} --experimental-control-plane"
done

echo "Cluster create finished."


echo "Plugin install finished."
echo "Waiting for all pods into 'Running' status. You can press 'Ctrl + c' to terminate this waiting any time you like."
POD_UNREADY=`kubectl get pods -n kube-system 2>&1|awk '{print $3}'|grep -vE 'Running|STATUS'`
NODE_UNREADY=`kubectl get nodes 2>&1|awk '{print $2}'|grep 'NotReady'`
while [ "${POD_UNREADY}" != "" -o "${NODE_UNREADY}" != "" ]; do
  sleep 1
  POD_UNREADY=`kubectl get pods -n kube-system 2>&1|awk '{print $3}'|grep -vE 'Running|STATUS'`
  NODE_UNREADY=`kubectl get nodes 2>&1|awk '{print $2}'|grep 'NotReady'`
done

echo

kubectl get cs
kubectl get nodes
kubectl get pods -n kube-system

echo """
join command:
  `kubeadm token create --print-join-command`"""
