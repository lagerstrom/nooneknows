#!/bin/bash

TERRAFORM_ZIP='https://releases.hashicorp.com/terraform/0.8.2/terraform_0.8.2_linux_amd64.zip'
RED_TEXT="\e[31m"
GREEN_TEXT="\e[92m"
RESET_TEXT="\e[0m"


function install_terraform {
    echo -n -e "$RED_TEXT"
    echo "Terraform binary not found, will install terraform in current directory"
    echo -n -e "$RESET_TEXT"

    wget $TERRAFORM_ZIP -O terraform_amd64.zip &&\
	unzip terraform_amd64.zip &&\
	rm terraform_amd64.zip &&\
	echo -n -e "$GREEN_TEXT" &&\
    	echo "Terraform installation successful" &&\
	echo -n -e "$RESET_TEXT"
}

function show_help {
    echo "Below you will see the arguments you can use"
    echo "cloud-automation.sh <app> <environment> <num_servers> <server_size>"
    echo "Ex:"
    echo "cloud-automation.sh hello_world dev 2 t1.micro 1"
}

function install_ansible {
    echo "You need to install ansible"
    exit 1
}

# Check if they just want to destroy the test env
if [ "$1" == "destroy" ]
   cd terraform
   ./terraform apply
   exit
fi

# check number of arguments
# cloud-automation.sh <app> <environment> <num_servers> <server_size>
# Santesize input should be done in a better way. This is just a PoC.
if [ "$#" -ne 4 ]; then
    show_help
    exit 1
fi

# Check if ansible is installed
type ansible >/dev/null 2>&1 || install_ansible


APP="$1"
AUTO_ENV="$2"
NUM_SERV="$3"
SERV_SIZE="$4"

# Sets up the environment with terraform
cd terraform
if [ ! -f "terraform" ];
then
    install_terraform
fi
./terraform apply -var "web_instances=$NUM_SERV"

WEB_IPS=$(./terraform output | grep webs | sed 's/webs = //')
DB_HOST=$(./terraform output | grep db | sed 's/db = //')
WEB_ADDRESS=$(./terraform output | grep address | sed 's/address = //')

cd ..
# End of the terraform part

# Lets start with configure our servers with ansible
cd ansible
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i "$WEB_IPS," -u ubuntu --extra-vars "wordpress_db_host=$DB_HOST" site.yml
cd ..
# Done with the ansible part

# Just need to echo out the web address
echo "Web address: $WEB_ADDRESS"
