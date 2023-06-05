resource "aws_s3_bucket" "test_log_bucket" {
  bucket = var.bucket_name
}
resource "aws_s3_bucket_ownership_controls" "test_log_bucket_ownership_controls" {
  bucket = aws_s3_bucket.test_log_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_public_access_block" "test_log_bucket_public_access_block" {
  bucket = aws_s3_bucket.test_log_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_acl" "test_log_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.test_log_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.test_log_bucket_public_access_block,
  ]

  bucket = aws_s3_bucket.test_log_bucket.id
  acl    = "public-read"
}
