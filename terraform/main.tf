# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "load_balancer_security_group"
  description = "Security group for the load balancer"
  vpc_id      = "${aws_vpc.default.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# A security group for the database
resource "aws_security_group" "db" {
  name        = "security_group_database"
  description = "Used for the database"
  vpc_id      = "${aws_vpc.default.id}"

  # MySQL access from the VPC
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "default_security_group"
  description = "This is the default security group"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "web" {
  name = "load-balancer"

  subnets         = ["${aws_subnet.default.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web.*.id}"]

  health_check {
    healthy_threshold = 2
    target = "TCP:80"
    unhealthy_threshold = 10
    timeout = 4
    interval = 5
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}


resource "aws_lb_cookie_stickiness_policy" "sticky_web" {
  name = "sticky-policy"
  load_balancer = "${aws_elb.web.id}"
  lb_port = 80
  cookie_expiration_period = 600
}


resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "web" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"

    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "${var.instance_size}"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.default.id}"

  # How many of this particular instace I would like to have
  count = "${var.web_instances}"

  tags {
    Name = "web_instance-${count.index}"
  }

  # We run a remote provisioner on the instance after creating it.
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
    ]
  }
}



# Create a subnet to launch our db instances into
resource "aws_subnet" "db1" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  #availability_zone       = "eu-west-1a"
  availability_zone       = "${var.aws_region}a"
}

# Create a subnet to launch our db instances into
resource "aws_subnet" "db2" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}b"
  #availability_zone       = "eu-west-1b"
}


resource "aws_db_subnet_group" "default" {
  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_ids = ["${aws_subnet.db1.id}", "${aws_subnet.db2.id}"]
  name = "my_database_subnet_group"
}

resource "aws_db_instance" "default" {
  allocated_storage    = 5
  engine               = "mysql"
  engine_version       = "5.6.27"
  instance_class       = "db.t1.micro"
  name                 = "mydb"
  username             = "test_user"
  password             = "testingpassword"
  multi_az             = false

  # Our Security group to allow MySQL access
  vpc_security_group_ids = ["${aws_security_group.db.id}"]

  # Creates the db host in the same VPC as the elb and the EC2 machines
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"

}
