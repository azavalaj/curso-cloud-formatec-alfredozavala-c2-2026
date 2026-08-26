resource "aws_s3_bucket" "bucket_a" {
  bucket        = "m4-c1-a-${local.bucket_suffix}"
  force_destroy = true

  tags = {
    Name = "m4-c1-a-${local.bucket_suffix}"
  }
}

resource "aws_s3_bucket" "bucket_b" {
  bucket        = "m4-c1-b-${local.bucket_suffix}"
  force_destroy = true

  tags = {
    Name = "m4-c1-b-${local.bucket_suffix}"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_a" {
  bucket                  = aws_s3_bucket.bucket_a.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "bucket_b" {
  bucket                  = aws_s3_bucket.bucket_b.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_a" {
  bucket = aws_s3_bucket.bucket_a.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_b" {
  bucket = aws_s3_bucket.bucket_b.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "bucket_a" {
  bucket = aws_s3_bucket.bucket_a.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "bucket_b" {
  bucket = aws_s3_bucket.bucket_b.id

  versioning_configuration {
    status = "Enabled"
  }
}
