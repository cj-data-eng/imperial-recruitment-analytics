# Printed after `terraform apply`, so you can see the bucket's name.
output "raw_bucket_name" {
  value = aws_s3_bucket.raw.id
}

output "ci_plan_role_arn" {
  value = aws_iam_role.ci_plan.arn
}

output "ci_apply_role_arn" {
  value = aws_iam_role.ci_apply.arn
}