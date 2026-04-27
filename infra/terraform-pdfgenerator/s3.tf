#s3 bucket role

resource "aws_s3_bucket" "pdf_storage" {
  bucket = var.s3_bucket_name
  tags = {
    Name = "PDF Storage"
  }
}

resource "aws_s3_bucket_versioning" "pdf_storage" {
  bucket = aws_s3_bucket.pdf_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "pdf_storage" {
  bucket = aws_s3_bucket.pdf_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


