variable "aws_region" {
  description = "aws region"
  type = string
  default = "us-east-1"

}

variable "cluster_name" {
   description = "cluster name"
   type = string
   default     = "pdf-generator-cluster"

}

variable "environment" {
  description = "env name"
  type = string
  default = "production"
}

variable "db_username" {
  description = "database username"
  type = string
  default = "dbadmin"

}

variable "db_name" {
  description = "database-name"
  type = string
  default = "mydatabase"
}

variable "s3_bucket_name" {
  description = "this is s3 bucket name"
  type = string
  default = "pdf-generator-sandeshgowda"
}