provider "aws" {
  profile    = "default"
  region     = "us-east-1"
}
variable "vpc_id" {
  default = "vpc-3e34b743"
}
variable "infrastructure_version" {
  default = "2"
}
terraform {
  backend "s3" {
    encrypt = true
    bucket  = "terraform-bluegreen-testhelloworld"
    region  = "us-east-1"
    key     = "v2"
  }
}
locals {
  subnet_count       = 1
  availability_zones = ["us-east-1a"]
}

resource "aws_subnet" "terraform-blue-greenv2" {
  count                   = "${local.subnet_count}"
  vpc_id                  = "${var.vpc_id}"
  availability_zone       = "${element(local.availability_zones, count.index)}"
  cidr_block              = "172.31.${local.subnet_count * (var.infrastructure_version - 0) + count.index + 2}.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${element(local.availability_zones, count.index)} (v${var.infrastructure_version})"
  }
}

locals {
  subnets = "${aws_subnet.terraform-blue-greenv2.*.id}"
  }

resource "aws_instance" "examplev2" {
    count  = 1
    ami = "ami-20ff515a"
    instance_type = "t2.small"
    subnet_id              = "${element(local.subnets, count.index)}"
    vpc_security_group_ids = ["${aws_security_group.instancev2.id}"]
    key_name               = "terraform-bluegreen"
# add
    user_data = <<-EOF
                #! /bin/bash
                sudo yum update
                sudo yum install -y httpd
                sudo chkconfig httpd on
                sudo service httpd start
                echo "<h1>hello world</h1>" | sudo tee /var/www/html/index.html
                EOF

    tags = {
        Name = "terraform-blue"
    }
}

resource "aws_security_group" "instancev2" {
    name = "terraform-example-instancev2"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


  resource "aws_lb_target_group_attachment" "terraform-1" {
    target_group_arn                    = "arn:aws:elasticloadbalancing:us-east-1:376048985616:targetgroup/terraform-bluegreen/0b7aabebcfae1ac9"
    target_id                           = "${aws_instance.examplev2.0.id}"
    port                                = 80
  }
