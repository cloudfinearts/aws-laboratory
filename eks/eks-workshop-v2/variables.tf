variable "cluster_name" {
  type    = string
  default = "eks-workshop"
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "ami_release_version" {
  type    = string
  default = "1.33.0-20250704"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "remote_network_cidr" {
  description = "Defines the remote CIDR blocks used on Amazon VPC created for Amazon EKS Hybrid Nodes."
  type        = string
  default     = "10.52.0.0/16"
}

variable "remote_pod_cidr" {
  description = "Defines the remote CIDR blocks used on Amazon VPC created for Amazon EKS Hybrid Nodes."
  type        = string
  default     = "10.53.0.0/16"
}
