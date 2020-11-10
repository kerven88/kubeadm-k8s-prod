``` shell
#克隆部署脚本,线上需要手动上传,线上需要切换到prod分支
#git clone http://git.sui.work/ops/kubeadm-k8s.git

# 编辑集群信息文件
# cat ./cluster-info
CP0_IP=10.201.3.221              #master-01 IP
CP1_IP=10.201.3.222              #master-02 IP 
CP2_IP=10.201.3.223              #master-03 IP
API_SERVER_NAME=k8sapi.feidee.cn #k8sapi域名
NET_IF=eth0                      #机器主网卡名称
CIDR=10.244.0.0/16               #k8s内网网段
REGISTYR=reg.feidee.org          #私有仓库域名

#执行集群安装脚本,安装过程需要交互输入osadmin密码
# /bin/sudo /bin/bash init_k8s_master.sh

#安装完成之后,我们发现kube-api还没做到高可用,这里的做法是每个机房是一个高可用的负载均衡入口，然后每个机房单独解析域名到对应的高可用入口
#然后部署nignx的tcp代理，把请求转发到三台master的IP:6443，这里注意入口监听的端口16443，不能修改。nginx的tcp代理配置如下:

stream {
log_format proxy '$remote_addr [$time_local] '
                 '$protocol $status $bytes_sent $bytes_received '
                 '$session_time "$upstream_addr" '
                 '"$upstream_bytes_sent" "$upstream_bytes_received" "$upstream_connect_time"';

    access_log /var/log/nginx/tcp-access.log proxy ;
    open_log_file_cache off;

    upstream apiserver {
        server K8SHA_IP1:6443 weight=5 max_fails=3 fail_timeout=30s;
        server K8SHA_IP2:6443 weight=5 max_fails=3 fail_timeout=30s;
        server K8SHA_IP3:6443 weight=5 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 16443;
        proxy_connect_timeout 1s;
        proxy_timeout 3s;
        proxy_pass apiserver;
    }
}


这段配置放在nginx主配置文件里面,且和nginx的http段上下文独立分开,如有有疑问,可查看部署脚本里面的nginx-lb里面的总体配置模板。
按照经验,每个业务的机房内部都有高可用入口(注意,api入口不能对外),我们只需要在对应的入口机器安装大于1.9版本的nginx(因为我们现有的tenginx不支持tcp代理)
再加上这段配置即可,启动nginx,然后域名解析到对应入口VIP,然后查看/var/log/nginx/tcp-access.log 看是否正常
nginx安装步骤:
centos6:
yum install -y  http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm
yum install -y nginx
cat nginx-lb/nginx-lb.conf > /etc/nginx/nginx.conf
/etc/init.d/nginx start
chkconfig nginx on

centos7:
yum install -y  http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum install -y nginx
cat nginx-lb/nginx-lb.conf > /etc/nginx/nginx.conf
systemctl start nginx
systenctl enable nginx


#增加工作节点到集群,安装过程需要交互输入osadmin密码
# /bin/sudo /bin/bash init_k8s_node.sh
```
