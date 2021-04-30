## kubeadm setup

### Abstract
We will prepare 3 virtual nodes and deploy Kubernetes with kubeadm.

- 1 Master nodes (2 CPU, 2 GB RAM)
- 2 Worker nodes (1 CPU, 1 GB RAM)

### Step 1. Install Kubernetes Servers

* Generate passwordless SSH key for user myansible
```
ssh-keygen
```
* Then add the public key to the section "import ssh key" in ./vagrant/bootstrap.sh
Vagrant creates a user "myansible" on all machines and drops the public key there.

```
vagrant up
```
* Add the content of file "/files/hosts" to your local /etc/hosts and on all nodes

* First ssh into all machines to add them to the known hosts
```
ssh myansible@master
ssh myansible@172.27.0.100
ssh myansible@node1
ssh myansible@172.27.0.101
ssh myansible@node2
ssh myansible@172.27.0.102
```

* Once the servers are ready, update them.
```
sudo apt update
sudo apt -y upgrade && sudo systemctl reboot
```

### Step 2: Install kubelet, kubeadm and kubectl
* Do this on all nodes

* Once the servers are rebooted, add Kubernetes repository for Ubuntu 20.04 to all the servers.
```
sudo apt update
sudo apt -y install curl apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

* Then install required packages.
```
sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

* Confirm installation by checking the version of kubectl.
```
$ kubectl version --client && kubeadm version
Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.3", GitCommit:"2e7996e3e2712684bc73f0dec0200d64eec7fe40", GitTreeState:"clean", BuildDate:"2020-05-20T12:52:00Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
kubeadm version: &version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.3", GitCommit:"2e7996e3e2712684bc73f0dec0200d64eec7fe40", GitTreeState:"clean", BuildDate:"2020-05-20T12:49:29Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
```

### Step 3: Disable Swap
* Do this on all nodes

* Turn off swap.
```
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a
```

* Configure sysctl.
```
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

### Step 4: Install Container runtime
* Do this on all nodes

* To run containers in Pods, Kubernetes uses a container runtime. Supported container runtimes are:

- Docker
- CRI-O
- Containerd

NOTE: You have to choose one runtime at a time.

#### Option 1: Installing Docker runtime:
```
# Add repo and Install packages
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io docker-ce docker-ce-cli

# Create required directories
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Services
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker
```

#### Option 2: Installing CRI-O:
```
# Ensure you load modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload sysctl
sudo sysctl --system

# Add repo
. /etc/os-release
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x${NAME}_${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/x${NAME}_${VERSION_ID}/Release.key -O- | sudo apt-key add -
sudo apt update

# Install CRI-O
sudo apt install cri-o-1.17

# Start and enable Service
sudo systemctl daemon-reload
sudo systemctl start crio
sudo systemctl enable crio
```

#### Option 3: Installing Containerd:
```
# Configure persistent loading of modules
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

# Load at runtime
sudo modprobe overlay
sudo modprobe br_netfilter

# Ensure sysctl params are set
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload configs
sudo sysctl --system

# Install required packages
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates


# Add Docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
sudo apt update
sudo apt install -y containerd.io

# Configure containerd and start service
sudo mkdir -p /etc/containerd
sudo su -

# Optionally print a default config for containerd 
# containerd config default  /etc/containerd/config.toml

# take our prepared config file from ./kubeadm/cri/containerd/config.toml
# and copy to /etc/containerd/config.toml

# restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
```
To use the systemd cgroup driver, set <b> plugins.cri.systemd_cgroup = true </b> in <b>/etc/containerd/config.toml</b>. 
When using kubeadm, manually configure the cgroup driver for kubelet. 


### Step 5: Initialize master node
* Do this only on master node

* Login to the server to be used as master and make sure that the br_netfilter module is loaded:
```
$ lsmod | grep br_netfilter
br_netfilter           22256  0 
bridge                151336  2 br_netfilter,ebtable_broute
```

* Enable kubelet service.
```
sudo systemctl enable kubelet
```
We now want to initialize the machine that will run the control plane components which includes etcd (the cluster database) and the API Server.

* Pull container images:
```
$ sudo kubeadm config images pull
[config/images] Pulled k8s.gcr.io/kube-apiserver:v1.18.3
[config/images] Pulled k8s.gcr.io/kube-controller-manager:v1.18.3
[config/images] Pulled k8s.gcr.io/kube-scheduler:v1.18.3
[config/images] Pulled k8s.gcr.io/kube-proxy:v1.18.3
[config/images] Pulled k8s.gcr.io/pause:3.2
[config/images] Pulled k8s.gcr.io/etcd:3.4.3-0
[config/images] Pulled k8s.gcr.io/coredns:1.6.7
```

* These are the basic <b>kubeadm init</b> options that are used to bootstrap cluster.
```
--control-plane-endpoint :  set the shared endpoint for all control-plane nodes. Can be DNS/IP
--pod-network-cidr : Used to set a Pod network add-on CIDR
--cri-socket : Use if have more than one container runtime to set runtime socket path
--apiserver-advertise-address : Set advertise address for this particular control-plane node's API server
```

* Set cluster endpoint DNS name or add record to /etc/hosts file.
```
$ sudo vim /etc/hosts
172.27.0.100 k8s-cluster
```

* Create cluster:
```
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --control-plane-endpoint=k8s-cluster \
  --apiserver-advertise-address=172.27.0.100 \
  --cri-socket=/run/containerd/containerd.sock
```
Note: If 192.168.0.0/16 is already in use within your network you must select a different pod network CIDR, replacing 192.168.0.0/16 in the above command.

Kubernetes network plugins (cni plugins)

Default network ranges:

- Calico: 192.168.0.0/16
- Flannel: 10.244.0.0/16
- WeaveNet: 10.32.0.0/12
- Cilium: 10.217.0.0/16
- Contiv: 10.1.0.0./16

* Container runtime sockets:

Runtime: Path to socket
- Docker: /var/run/docker.sock
- CRI-O: /var/run/crio/crio.sock
- Containerd: /run/containerd/containerd.sock

You can optionally pass Socket file for runtime and advertise address depending on your setup.

* Then obtain tokens for other nodes to join from console output:
```
# example of my output:
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join k8s-cluster:6443 --token lsupuh.1mmmzphtdfbjjgsn \
	--discovery-token-ca-cert-hash sha256:9dab404c6da1a62347d6fcba659f521f6fdf296b6513b54be2809c4ca96a5691 \
	--control-plane 

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join k8s-cluster:6443 --token lsupuh.1mmmzphtdfbjjgsn \
	--discovery-token-ca-cert-hash sha256:9dab404c6da1a62347d6fcba659f521f6fdf296b6513b54be2809c4ca96a5691
```

* Configure kubectl using commands in the output:
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

* Check cluster status:
```
$ kubectl cluster-info
Kubernetes master is running at https://k8s-cluster.computingforgeeks.com:6443
KubeDNS is running at https://k8s-cluster.computingforgeeks.com:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

* Additional Master nodes can be added using the command in installation output:
```
kubeadm join k8s-cluster.computingforgeeks.com:6443 --token sr4l2l.2kvot0pfalh5o4ik \
    --discovery-token-ca-cert-hash sha256:c692fb047e15883b575bd6710779dc2c5af8073f7cab460abd181fd3ddb29a18 \
    --control-plane 
```

### Step 6: Install network plugin on Master
* Do this only on master node

* Depending from the CNI plugin you chose, your pods will receive their IP addresses
  from the CNI plugin's default IP range. In this guide we’ll use Calico. You can choose any other supported network plugins.
```
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

* Confirm that all of the pods are running:
```
$ watch kubectl get pods --all-namespaces
```

* Confirm master node is ready:
```
$ kubectl get nodes -o wide
```

### Step 7: Add worker nodes
* Do this on each worker node you want to join the cluster

With the control plane ready you can add worker nodes to the cluster for running scheduled workloads.

* If endpoint address is not in DNS, add record to /etc/hosts.
```
$ sudo vim /etc/hosts
172.27.0.100 k8s-cluster
```

* The join command that was given is used to add a worker node to the cluster.
```
kubeadm join k8s-cluster.computingforgeeks.com:6443 \
  --token sr4l2l.2kvot0pfalh5o4ik \
  --discovery-token-ca-cert-hash sha256:c692fb047e15883b575bd6710779dc2c5af8073f7cab460abd181fd3ddb29a18
```

* Run below command on the control-plane to see if the node joined the cluster.
```
$ kubectl get nodes
```

### Step 8: Create nginx workload
* Do this from your kubectl client host (maybe your laptop)

* Let us deploy a first real little workload, we chose nginx webserver.
```
kubectl -n default create deployment nginx --image=nginx --replicas=2
```

## Links, Info, Reference
* This tutorial is mainly based on:
https://computingforgeeks.com/deploy-kubernetes-cluster-on-ubuntu-with-kubeadm/

* Comparison of kubernetes CNI plugins
https://github.com/weibeld/cni-plugin-comparison

* What is kubeadm?
https://github.com/kubernetes/kubeadm
  
* Calico: configure default network interface
https://docs.projectcalico.org/networking/ip-autodetection

* Kubernetes on Virtualbox
https://medium.com/@ErrInDam/taming-kubernetes-for-fun-and-profit-60a1d7b353de
  
* How to setup Docker on CentOS
https://phoenixnap.com/kb/how-to-install-docker-centos-7

* Container Runtimes:
https://www.threatstack.com/blog/diving-deeper-into-runtimes-kubernetes-cri-and-shims
  
* Kubernetes Docker Deprecation
https://acloudguru.com/blog/engineering/kubernetes-is-deprecating-docker-what-you-need-to-know
  
