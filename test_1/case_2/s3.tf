resource "aws_s3_bucket" "test_1" {
  bucket = var.bucket_name
  force_destroy = true
  acl    = "private"
}
