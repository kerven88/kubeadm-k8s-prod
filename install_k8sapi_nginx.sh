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


check_parm "请输入单个机房需要部署k8sapi的nginx tcp代理的入口的两个IP,IP之间以英文逗号隔开: " ${WORKER_IP} 
if [ $? -eq 1 ]; then
	read WORKER_IP
fi

check_parm "请确认以上两台机器是否已经部署keepalived(yes/no): " ${ANSWER}
if [ $? -eq 1 ]; then
        read ANSWER
fi
snswer=${ANSWER}

ip_array=(${WORKER_IP//,/ })
if [ "${snswer}" == 'yes' ]; then


echo """
k8s api入口部署信息:
  需要部署nginx的机器:        ${ip_array[@]}
  是否已经部署keepalived:     ${snswer}
  注意!!!
  1.确定IP信息正确.
  3.确保是以root用户在master-01上面执行这个脚本,节点的osadmin账号拥有sudo权限.
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
for ip in  ${ip_array[@]}; do
 scp nginx-lb/nginx-lb.conf   osadmin@${ip}:/tmp/
 ssh osadmin@$ip "/bin/sudo yum install nginx -y && /bin/sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf_bak && mv /tmp/nginx-lb.conf /etc/nginx/nginx.conf && /etc/init.d/nginx start"
 echo "nginx tcp代理已经安装成功,请把k8sapi域名解析到这个入口的VIP"
done

elif [ "${snswer}" == 'no' ];then
check_parm "请输入机房1需要的vip: " ${VIP}
if [ $? -eq 1 ]; then
        read VIP
fi
vip=${VIP}

check_parm "请输入需要挂载vip的实体网卡名称(如eth0): " ${NET_IF}
if [ $? -eq 1 ]; then
        read NET_IF
fi
net_if=${NET_IF}
echo """
k8s api入口部署信息:
  需要部署nginx的机器:        ${ip_array[@]}
  是否已经部署keepalived:     ${snswer}
  VIP是:                      ${vip}
  网卡名称:                   ${net_if}
  注意!!!
  1.确定IP信息正确.
  3.确保是以root用户在master-01上面执行这个脚本,节点的osadmin账号拥有sudo权限.
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


for ip in  ${ip_array[@]}; do
 scp nginx-lb/nginx-lb.conf   osadmin@${ip}:/tmp/
 ssh osadmin@$ip "/bin/sudo yum install nginx -y && /bin/sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf_bak && mv /tmp/nginx-lb.conf /etc/nginx/nginx.conf && /etc/init.d/nginx start"

 scp keepalived.tar.gz  osadmin@${ip}:/tmp/
 ssh osadmin@${ip} "
 /bin/sudo /bin/mv -f /tmp/keepalived.tar.gz /usr/local/src/ && cd /usr/local/src/ && /bin/sudo /bin/tar -zxvf keepalived.tar.gz && /bin/sudo /bin/bash keepalived.sh"
done

id=`echo $vip |awk -F "." '{print $4}'`

ip=${ip_array[0]}
echo $ip
sed \
-e "s/VIP/${vip}/g" \
-e "s/NET_IF/${net_if}/g" \
-e "s/ID/${id}/g" \
-e "s/PRIORITY/150/g" \
keepalived.conf.tpl > keepalived.conf_master
scp keepalived.conf_master osadmin@${ip}:/tmp/
ssh osadmin@$ip "/bin/sudo mv -f /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf_bak && /bin/sudo mv /tmp/keepalived.conf_master  /etc/keepalived/keepalived.conf && /bin/sudo /etc/init.d/keepalived restart"
ip=${ip_array[1]}
echo $ip
sed \
-e "s/VIP/${vip}/g" \
-e "s/NET_IF/${net_if}/g" \
-e "s/ID/${id}/g" \
-e "s/PRIORITY/100/g" \
keepalived.conf.tpl > keepalived.conf_backup

scp keepalived.conf_backup osadmin@${ip}:/tmp/
ssh osadmin@$ip "/bin/sudo mv -f /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf_bak && /bin/sudo mv /tmp/keepalived.conf_master  /etc/keepalived/keepalived.conf && /bin/sudo /etc/init.d/keepalived restart"
sleep 5
packetloss=`/bin/ping ${vip}   -c 2 |grep received |awk -F, '{print $3 }'|awk -F "%" '{print $1}'`
if [ $packetloss = 100 ];then
echo "vip未挂起,请到对应主机查询原因"
else
echo "vip已经正常ping通,检查nginx tcp代理正常后请把k8sapi域名解析到vip上" 
fi
fi
