terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state: Terraform's memory of what it built is stored in S3.
  # Paste your state bucket name below. If the grocery project's backend
  # block has extra lines (like dynamodb_table or use_lockfile), copy them in too.
  backend "s3" {
    bucket = "terraform-state-prod-511454199223-eu-west-2-an"
    key    = "imperial-recruitment/dev/terraform.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"

  # Tags are labels stamped on everything Terraform creates.
  # They help you find things and track costs later.
  default_tags {
    tags = {
      project     = "imperial-recruitment-analytics"
      environment = "dev"
      managed_by  = "terraform"
    }
  }
}

# Ask AWS "who am I?" so we can use the account ID in the bucket name.
data "aws_caller_identity" "current" {}

locals {
  # Bucket names must be unique worldwide. Adding your account ID
  # makes a clash with anyone else's bucket practically impossible.
  raw_bucket_name = "recruitment-analytics-raw-${data.aws_caller_identity.current.account_id}"
}

# The bucket itself: the landing zone for raw CSV files.
resource "aws_s3_bucket" "raw" {
  bucket = local.raw_bucket_name
}

# Safety: never allow this bucket to be made public.
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Safety: keep old versions of files, so an accidental overwrite can be undone.
resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Safety: encrypt everything stored in the bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Athena writes a result file for every query. Delete them after a week
# so scratch output doesn't pile up (and cost money).
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "expire-athena-query-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/"
    }

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  # Versioning must be switched on before lifecycle rules are added.
  depends_on = [aws_s3_bucket_versioning.raw]
}