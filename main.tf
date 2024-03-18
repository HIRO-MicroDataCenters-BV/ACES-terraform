provider "aws" {
  region = var.region
}

module "cluster_1" {
  source = "./terraform-aws-kubeadm"

  cluster_name         = var.cluster_names[0]
  master_instance_type = var.instance_type
  worker_instance_type = var.instance_type
  num_workers          = 1
}

module "cluster_2" {
  source = "./terraform-aws-kubeadm"

  cluster_name         = var.cluster_names[1]
  master_instance_type = var.instance_type
  worker_instance_type = var.instance_type
  num_workers          = 1
}
