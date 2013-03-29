#TAGS=-t keystone
#CHECK=--check

ANSIBLE=ansible-playbook -v $(TAGS) $(CHECK)

.PHONY: all vms openstack controller keystone glance nova-controller vms compute destroy

openstack: openstack-ansible-modules
	$(ANSIBLE) openstack.yaml

openstack-ansible-modules:
	git submodule init
	git submodule update

all: openstack-ansible-modules vms openstack

vms:
	cd vms; vagrant up
destroy:
	cd vms; vagrant destroy --force


