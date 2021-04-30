# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|

  # k8s Master
  config.vm.define "master" do |master|
    #master.vm.box = "centos/7"
    master.vm.box = "ubuntu/focal64"
    master.vm.hostname = "master.k8s.local"
    ## create a VM with implicit Adapter1: NAT (for vagrant) and Adapter2: HOST-ONLY reachable from laptop only
    master.vm.network "private_network", ip: "172.27.0.100"
    ## create a VM with implicit Adapter1: NAT and Adapter2: BRIDGE reachable in our network
    #master.vm.network "public_network", bridge: 'wlp2s0', adapter:2
    master.vm.provider "virtualbox" do |v|
      v.name = "master"
      v.memory = 2048
      v.cpus = 2
    end
    master.vm.provision "shell", path: "vagrant/bootstrap.sh"
  end

  NodeCount = 2

  # k8s Nodes
  (1..NodeCount).each do |i|
    config.vm.define "node#{i}" do |node|
      #node.vm.box = "centos/7"
      node.vm.box = "ubuntu/focal64"
      node.vm.hostname = "node#{i}.k8s.local"
      ## create a VM with implicit Adapter1: NAT (for vagrant) and Adapter2: HOST-ONLY reachable from laptop only
      node.vm.network "private_network", ip: "172.27.0.10#{i}"
      ## create a VM with implicit Adapter1: NAT and Adapter2: BRIDGE reachable in our network
      #node.vm.network "public_network", bridge: 'wlp2s0', adapter:2
      node.vm.provider "virtualbox" do |v|
        v.name = "node#{i}"
        v.memory = 2048
        v.cpus = 1
      end
      node.vm.provision "shell", path: "vagrant/bootstrap.sh"
    end
  end
end