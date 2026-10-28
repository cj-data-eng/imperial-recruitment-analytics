# Printed after `terraform apply`, so you can see the bucket's name.
output "raw_bucket_name" {
  value = aws_s3_bucket.raw.id
}