terraform {
  backend "s3" {
    bucket       = "fintech-bucket-all"
    key          = "pdf-generator/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

  }

}