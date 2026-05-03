variable "region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "eks_node_sg_id" {
  description = "The Security Group ID of your EKS worker nodes"
  type        = string
}

variable "external_ip" {
  description = "Your local/app IP (e.g., 1.2.3.4/32)"
  type        = string
  default = "0.0.0.0/0"
}
variable "cluster_name" {
  description = "The name of your existing EKS cluster"
  type        = string
  default     = "my-eks-cluster" # Change this to your actual cluster name
}