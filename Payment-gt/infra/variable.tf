variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "cluster_name" {
  type    = string
  default = "core-eks"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.small", "t3.medium","t2.micro","t3.micro"] # Combines highly affordable low-tier architectures
}

variable "db_username" {
  type        = string
  description = "The database administrator master account username token string"
  default     = "dbadmin"
}



