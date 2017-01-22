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

cd terraform
if [ ! -f "terraform" ];
then
    install_terraform
fi
