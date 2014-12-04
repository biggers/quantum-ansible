#!/bin/bash

set -x
set -e

# source quantum-ansible.rc
. /vagrant/openrc

nova flavor-create micro 6 50 0 1 || echo "failed"

TEST_KEY=/vagrant/test-key
# TEST_KEY=./test-key
chmod 0600 ${TEST_KEY}
nova keypair-add --pub-key ${TEST_KEY}.pub test-key

neutron net-create net1
neutron subnet-create net1 10.0.33.0/24 --name=sub1 --dns_nameservers 8.8.4.4 8.8.8.8

neutron net-create ext-net --provider:network_type local --router:external true
neutron subnet-create ext-net 192.168.101.0/24 --enable_dhcp False --name ext-sub

neutron router-create router1
neutron router-gateway-set router1 ext-net
neutron router-interface-add router1 sub1

TEST_SG=test-vms
neutron security-group-create $TEST_SG --description "allow ping and ssh"
neutron security-group-rule-create --protocol icmp --direction ingress \
        --remote-ip-prefix 0.0.0.0/0 $TEST_SG
neutron security-group-rule-create --protocol tcp --port-range-min 22 \
	--port-range-max 22 --direction ingress --remote-ip-prefix 0.0.0.0/0 $TEST_SG


PORT_ID=$(neutron port-create --security-group $TEST_SG net1 \
          -f shell --variable id | grep '^id=' | cut -d= -f2 | tr -d '"')

sleep 5 # TODO find out why dhcp replies are dropped w/o this delay

VM=vm_tng
nova boot --flavor micro --image cirros-0.3.1-x86_64 --nic port-id=$PORT_ID --key-name test-key --security-group $TEST_SG   ${VM}


FLOAT_ID=$(neutron floatingip-create ext-net | grep ' id ' | awk '{print $4;}')
VM_ID=$(nova list | grep ${VM} | awk '{print $2;}')


neutron floatingip-associate $FLOAT_ID $PORT_ID
neutron floatingip-show $FLOAT_ID

eval `neutron floatingip-show -f shell --variable floating_ip_address $FLOAT_ID`
echo "Give VM a minute to boot before trying ssh -i vms/test-key cirros@${floating_ip_address} from main host"



