variable "cluster_names" {
  type        = tuple([string, string])
  description = "Names for the individual clusters. If the value for a specific cluster is null, a random name will be automatically chosen."
  default     = [null, null]
}

variable "region" {
  type        = string
  description = "AWS region in which to create the clusters."
  default     = "eu-west-3"
}

variable "instance_type" {
  type        = string
  description = "AWS instance type use for all machine"
  default     = "i4i.large"
}
