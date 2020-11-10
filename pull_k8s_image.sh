#!/bin/bash
#把k8s从外网同步下来上传到内部仓库
registry_host=registry.feidee.org
version=v1.13.4
pause_version=3.1
etcd_version=3.2.24
coredns_version=1.2.6

docker pull mirrorgooglecontainers/kube-apiserver:$version
docker pull mirrorgooglecontainers/kube-controller-manager:$version
docker pull mirrorgooglecontainers/kube-scheduler:$version
docker pull mirrorgooglecontainers/kube-proxy:$version
docker pull mirrorgooglecontainers/pause:$pause_version
docker pull mirrorgooglecontainers/etcd:$etcd_version
docker pull coredns/coredns:$coredns_version

docker tag mirrorgooglecontainers/kube-apiserver:$version      $registry_host/library/kube-apiserver:$version
docker tag mirrorgooglecontainers/kube-controller-manager:$version $registry_host/library/kube-controller-manager:$version
docker tag mirrorgooglecontainers/kube-scheduler:$version $registry_host/library/kube-scheduler:$version
docker tag mirrorgooglecontainers/kube-proxy:$version $registry_host/library/kube-proxy:$version
docker tag mirrorgooglecontainers/pause:$pause_version $registry_host/library/pause:$pause_version
docker tag mirrorgooglecontainers/etcd:$etcd_version  $registry_host/library/etcd:$etcd_version
docker tag coredns/coredns:$coredns_version  $registry_host/library/coredns:$coredns_version

docker push $registry_host/library/kube-apiserver:$version
docker push $registry_host/library/kube-controller-manager:$version
docker push $registry_host/library/kube-scheduler:$version
docker push $registry_host/library/kube-proxy:$version
docker push $registry_host/library/pause:$pause_version
docker push $registry_host/library/etcd:$etcd_version
docker push $registry_host/library/coredns:$coredns_version

docker pull $registry_host/library/kube-apiserver:$version
docker pull $registry_host/library/kube-controller-manager:$version
docker pull $registry_host/library/kube-scheduler:$version
docker pull $registry_host/library/kube-proxy:$version
docker pull $registry_host/library/pause:$pause_version
docker pull $registry_host/library/etcd:$etcd_version
docker pull $registry_host/library/coredns:$coredns_version

docker tag $registry_host/library/kube-apiserver:$version k8s.gcr.io/kube-apiserver:$version
docker tag $registry_host/library/kube-controller-manager:$version  k8s.gcr.io/kube-controller-manager:$version
docker tag $registry_host/library/kube-scheduler:$version  k8s.gcr.io/kube-scheduler:$version
docker tag $registry_host/library/kube-proxy:$version  k8s.gcr.io/kube-proxy:$version
docker tag $registry_host/library/pause:$pause_version  k8s.gcr.io/pause:$pause_version
docker tag $registry_host/library/etcd:$etcd_version k8s.gcr.io/etcd:$etcd_version
docker tag $registry_host/library/coredns:$coredns_version  k8s.gcr.io/coredns:$coredns_version