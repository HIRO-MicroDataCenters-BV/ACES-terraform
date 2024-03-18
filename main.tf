provider "aws" {
  region = "eu-west-3"
}

locals {
  instance_type = "i4i.large"
  ami           = "ami-0cf8088cd49029d99"
}

module "cluster_1" {
  source = "github.com/RyaxTech/terraform-aws-kubeadm"

  cluster_name           = "aces-1"
  master_instance_type   = local.instance_type
  worker_instance_type   = local.instance_type
  num_workers            = 1
  pod_network_cidr_block = "10.42.0.0/16"
  service_cidr_block     = "10.43.0.0/16"
}


module "cluster_2" {
  source = "github.com/RyaxTech/terraform-aws-kubeadm"

  cluster_name           = "aces-2"
  master_instance_type   = local.instance_type
  worker_instance_type   = local.instance_type
  num_workers            = 1
  pod_network_cidr_block = "10.0.0.0/16"
  service_cidr_block     = "10.1.0.0/16"
}

resource "aws_security_group" "submariner" {
  name        = "inter-cluster-submariner"
  description = "Allow Submariner port"
  vpc_id      = module.cluster_1.vpc_id
  ingress {
    protocol  = "udp"
    from_port = 4500
    to_port   = 4500
    cidr_blocks = ["172.31.0.0/16"]
    # concat(
    #   [for node in module.cluster_1.cluster_nodes : "${node.public_ip}/32"],
    #   [for node in module.cluster_2.cluster_nodes : "${node.public_ip}/32"]
    # )
  }
  ingress {
    protocol  = "udp"
    from_port = 4490
    to_port   = 4490
    cidr_blocks = ["172.31.0.0/16"]
  }
  ingress {
    protocol  = "udp"
    from_port = 4800
    to_port   = 4800
    cidr_blocks = ["172.31.0.0/16"]
  }
}
