variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/terraform.pub
DESCRIPTION
default = "~/.ssh/id_rsa.pub"
}

variable "key_name" {
  description = "Desired name of AWS key pair"
  #default = "tesla"
  default = "cloud_automation"
}

variable "aws_region" {
  description = "AWS region to launch servers"
  default     = "eu-west-1"
}

variable "web_instances" {
  description = "Number of web instances"
  default = 1
}

variable "instance_size" {
  description = "Which instance type to use"
  default = "t2.micro"
}

variable "deploy_environment" {
  description = "Which environment you would like to use"
  default = "dev"

}

# Ubuntu Precise 14.04 LTS (x64)
variable "aws_amis" {
  default = {
    eu-west-1 = "ami-b6b394c5"
  }
}
