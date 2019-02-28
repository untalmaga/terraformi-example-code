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

module "cool-website-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "cool-website-sg"
  description = "SG for cool website"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "LB service ports"
      cidr_blocks = "10.0.0.0/16"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "LB service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_with_self = [
    {
      rule = "all-all"
    }
  ]
}

module "elb-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "elb-sg"
  description = "SG for ELB"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "LB service ports"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "LB service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_with_self = [
    {
      rule = "all-all"
    }
  ]
}

#####   END OF SECURITY GROUP MODULE 


## EC2 CREATION 
resource "aws_instance" "cool-website-instance" {
  ami           = "${var.ami-id}"
  instance_type = "t2.micro"
  key_name = "${var.aws-key-pair}"
  subnet_id = "${element(module.vpc.private_subnets, 0)}"
  vpc_security_group_ids = ["${module.cool-website-sg.this_security_group_id}"]
  tags = {
    Name = "cool-website"
  }

   provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install software-properties-common",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt-get install ansible git", 
      "sudo cd /tmp && sudo git clone https://github.com/untalmaga/ansible-terraformi.git",
      "sudo ansible-playbook playbook.yml"
    ]
  }
}

## LOAD BALANCER 

resource "aws_elb" "cool-website-lb" {
  name = "cool-website-lb"

  subnets         = ["${element(module.vpc.public_subnets, 0)}"]  
  security_groups = ["${module.elb-sg.this_security_group_id}"]
  instances       = ["${aws_instance.cool-website-instance.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}


// Una vez que la instancia está arriba, se debe de popular con Ansible. 


