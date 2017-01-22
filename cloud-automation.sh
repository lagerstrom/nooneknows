#!/bin/bash

TERRAFORM_ZIP='https://releases.hashicorp.com/terraform/0.8.2/terraform_0.8.2_linux_amd64.zip'
RED_TEXT="\e[31m"
GREEN_TEXT="\e[92m"
RESET_TEXT="\e[0m"

DEBUG=true

function execute_command {

    if [ "$DEBUG" = true ]; then
	$@
    else
	$@ > /dev/null
    fi

    RET_CODE=$?
    if [ "$RET_CODE" -ne 0 ]; then
	echo -n -e "$RED_TEXT"
	echo "Following command returned with value $RET_CODE"
	echo ""
	echo "$@"
	echo -n -e "$RESET_TEXT"
	exit $RET_CODE
    fi
}

# Ugly function which generate some json code for ansible.
# There is already a nginx load balancer container and instead
# of writing my own I'm using his. Not the best way but quickest
# for the moment
function generate_lb_config {
    config_file=$(tempfile -s ".json")
    #trap "rm $config_file" EXIT
    RET_VAL='{"env_dict": {"'

    COUNT=1
    for ip_num in $(echo "$1" | tr "," "\n"); do
	RET_VAL="$RET_VAL"'WORDPRESS_'"$COUNT"'_PORT_80_TCP_ADDR": "'"$ip_num"'", '
	((COUNT++))
    done
    COUNT=1

    RET_VAL="$RET_VAL"'"WORDPRESS_PATH": "/", "WORDPRESS_BALANCING_TYPE": "ip_hash"}}'
    echo "$RET_VAL" > "$config_file"
    echo "$config_file"
}


function install_terraform {
    echo -n -e "$RED_TEXT"
    echo "Terraform binary not found, will install terraform in current directory"
    echo -n -e "$RESET_TEXT"

    execute_command wget $TERRAFORM_ZIP -O terraform_amd64.zip
    execute_command unzip terraform_amd64.zip
    execute_command rm terraform_amd64.zip

    echo -n -e "$GREEN_TEXT"
    echo "Terraform installation successful"
    echo -n -e "$RESET_TEXT"
}

function install_ansible {
    echo -n -e "$RED_TEXT"
    echo "Ansible not found, will install now install ansible"
    echo -n -e "$RESET_TEXT"

    execute_command sudo apt-get -y install software-properties-common
    execute_command sudo apt-add-repository -y ppa:ansible/ansible
    execute_command sudo apt-get -y update
    execute_command sudo apt-get -y install ansible

    echo -n -e "$GREEN_TEXT"
    echo "Ansible installation successful"
    echo -n -e "$RESET_TEXT"
}

function show_help {
    echo "Below you will see the arguments you can use"
    echo "cloud-automation.sh <app> <environment> <num_servers> <server_size>"
    echo "Ex:"
    echo "cloud-automation.sh hello_world dev 2 t2.micro"
}

# Check if they just want to destroy the test env
if [ "$1" == "destroy" ]; then
   cd terraform
   ./terraform destroy
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

# Put the arguments in varaibles
APP="$1"
ENV="$2"
NUM_SERV="$3"
SERV_SIZE="$4"

# Sets up the environment with terraform
cd terraform
if [ ! -f "terraform" ];
then
    install_terraform
fi
execute_command ./terraform apply -var "web_instances=$NUM_SERV" -var "instance_size=$SERV_SIZE"

WEB_PUB=$(./terraform output | grep webs_pub | sed 's/webs_pub = //')
WEB_PRIV=$(./terraform output | grep webs_priv | sed 's/webs_priv = //')
DB_HOST=$(./terraform output | grep db_priv | sed 's/db_priv = //')
WEB_ADDRESS=$(./terraform output | grep address | sed 's/address = //')
DB_PUB=$(./terraform output | grep db_pub | sed 's/db_pub = //')
LB_PUB=$(./terraform output | grep lb_pub | sed 's/lb_pub = //')
LB_CONF=$(generate_lb_config "$WEB_PRIV")
trap "rm $LB_CONF" EXIT

cd ..
# End of the terraform part

# Lets start with configure our servers with ansible
cd ansible
export ANSIBLE_HOST_KEY_CHECKING=False
# Configure the database host
execute_command ansible-playbook -i "$DB_PUB," -u ubuntu db.yml
# Configure the web hosts
execute_command ansible-playbook -i "$WEB_PUB," -u ubuntu  --extra-vars "wordpress_version=$APP" --extra-vars "wordpress_db_host=$DB_HOST" web.yml
# Configure the load balancer
execute_command ansible-playbook -i "$LB_PUB,"  -u ubuntu  --extra-vars "@$LB_CONF" lb.yml
cd ..
# Done with the ansible part

# Just need to echo out the web address
echo "Web address: $WEB_ADDRESS"
