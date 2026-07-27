terraform {
  backend "s3" {
    bucket       = "sandesh-tf-file"
    key          = "payment-gateway/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true

    # Enables S3 Native State Locking (No DynamoDB table required)
    use_lockfile = true
  }
}
