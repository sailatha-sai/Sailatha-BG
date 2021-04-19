provider "aws" {
  profile    = "default"
  region     = "us-east-1"
}
variable "vpc_id" {
  default = "vpc-3e34b743"
}
variable "infrastructure_version" {
  default = "3"
}
terraform {
  backend "s3" {
    encrypt = true
    bucket  = "terraform-bluegreen-testhelloworld"
    region  = "us-east-1"
    key     = "v3"
  }
}
locals {
  subnet_count       = 2
  availability_zones = ["us-east-1a", "us-east-1b"]
}

resource "aws_subnet" "terraform-blue-green" {
  count                   = "${local.subnet_count}"
  vpc_id                  = "${var.vpc_id}"
  availability_zone       = "${element(local.availability_zones, count.index)}"
  cidr_block              = "172.31.${local.subnet_count * (var.infrastructure_version - 1) + count.index + 1}.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${element(local.availability_zones, count.index)} (v${var.infrastructure_version})"
  }
}

resource "aws_alb" "terraform" {
  name                                = "terraform-bluegreen"
  internal                            = false
  security_groups                     = ["${aws_security_group.instance.id}"]
  subnets                             = "${aws_subnet.terraform-blue-green.*.id}"
  enable_deletion_protection          = false
}
resource "aws_lb_target_group" "terraform" {
    depends_on                          = ["aws_alb.terraform"]
    name                                = "terraform-bluegreen"
    port                                = 80
    protocol                            = "HTTP"
    vpc_id                              = "${var.vpc_id}"
    deregistration_delay                = 10
    health_check {
      protocol                          = "HTTP"
      path                              = "/"
      port                              = "80"
      healthy_threshold                 = 2
      unhealthy_threshold               = 10
      timeout                           = 4
      interval                          = 5
      matcher                           = "200"
    }
  }

  resource "aws_alb_listener" "terraform" {
    depends_on                          = ["aws_alb.terraform", "aws_lb_target_group.terraform"]
    load_balancer_arn                   = "${aws_alb.terraform.arn}"
    port                                = "80"
    protocol                            = "HTTP"


    default_action {
      target_group_arn                  = "${aws_lb_target_group.terraform.arn}"
      type                              = "forward"
    }
  }

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"
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
