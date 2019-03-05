provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws-region}"

}

########
# NETWORKING
#######

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "cool-website-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-west-2a"]
  private_subnets = ["10.0.22.0/24"]
  public_subnets  = ["10.0.44.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "cool-website-vpc"
  }
}



// SECURITY GROUP
// Using VPC module 
// https://github.com/terraform-aws-modules/terraform-aws-security-group#security-group-with-predefined-rules

resource "aws_security_group" "cool-website-sg" {
  name   = "cool-website-sg"
  vpc_id = "${module.vpc.vpc_id}"

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

# ELB SG #
resource "aws_security_group" "elb-sg" {
  name   = "elb-sg"
  vpc_id = "${module.vpc.vpc_id}"

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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
#####   END OF SECURITY GROUP MODULE 


## EC2 CREATION 
resource "aws_instance" "cool-website-instance" {
  ami           = "${var.ami-id}"
  instance_type = "t2.micro"
  key_name = "${var.aws-key-pair}"
  subnet_id = "${element(module.vpc.public_subnets, 0)}"
  vpc_security_group_ids = ["${aws_security_group.cool-website-sg.id}"]
  
  connection {
    user = "ubuntu"
    private_key = "${var.ssh_key}"
  }

  tags = {
    Name = "cool-website"
  }

   provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install nginx -y && service nginx start",
      "sudo git clone https://github.com/untalmaga/code-cool-website.git /var/www/html/cool-website"
    ]
  }

  provisioner "file" {
    source = "conf/cool-website.conf"
    destination = "/tmp/cool-website.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/cool-website.conf /etc/nginx/sites-enabled/ && sudo rm /etc/nginx/sites-enabled/default",
      "sudo chown -R www-data:www-data /var/www/html/ ",
      "sudo chown www-data:www-data /etc/nginx/sites-enabled/cool-website.conf",
      "sudo service nginx restart"
    ]
  }
}

## LOAD BALANCER 

resource "aws_elb" "cool-website-lb" {
  name = "cool-website-lb"

  subnets         = ["${element(module.vpc.public_subnets, 0)}"]  
  security_groups = ["${aws_security_group.elb-sg.id}"]
  instances       = ["${aws_instance.cool-website-instance.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}


// Una vez que la instancia está arriba, se debe de popular con Ansible. 


