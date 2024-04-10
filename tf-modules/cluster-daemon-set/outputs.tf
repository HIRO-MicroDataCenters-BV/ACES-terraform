output "vpc_id" {
  value       = module.kubernetes_cluster.vpc_id
  description = "ID of the VPC in which the cluster has been created."
}