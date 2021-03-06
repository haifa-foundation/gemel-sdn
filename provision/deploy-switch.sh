#!/bin/bash

# get current file directory
DIR="$(realpath $( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd ))"
cd $DIR
source $DIR/../base/include.sh

print_help() {
    echo -e "Creates a new VM, installs VXLAN capable OVS on it,\n connects it to one of the so-called \"physical\" switches on the SDN lab through VXLAN."
    echo "./add-switch.sh [VM NAME] [CONTROLLER IP] [optional: ZONE]"
    exit 0
}

# print help and exit if not enough args given
[[ $# -ge 2 ]] || {
    print_help
    exit 1
}

# parse args
NAME="$1"
CONTROLLER_IP="$2"
ZONE="$3"

if [[ -z "$ZONE" ]]
then
    ZONE="us-east1-b"
fi

# create VM
log "creating VM $NAME"
$(realpath $DIR)/create-vm.sh "$NAME" "a" "$ZONE" || exit 1

# get VM IP address
VM_IP=$(gcloud compute instances list | grep $NAME | awk '{ print $5 }')
log "VM external IP address is $VM_IP"

# wait until SSH up
while [ true ]
do

    log "Waiting for VM to boot"
    SSH $NAME uptime

    if [ $? -eq 0 ]
    then
        break
    fi

done

# copy ansible playbook to host
log "updating scripts in VM"
SCP scripts $NAME:~ || exit 1

# install ansible
SSH $NAME 'sudo apt-add-repository ppa:ansible/ansible -y'
SSH $NAME 'sudo apt update'
SSH $NAME 'sudo apt install -y ansible'

# install OVS
SSH $NAME 'sudo ansible-playbook scripts/ovs.yml'

# init bridge
SSH $NAME "sudo ~/scripts/init-bridge.sh"

# set controller
SSH $NAME "sudo ~/scripts/set-controller.sh $CONTROLLER_IP"

log "Success!"


