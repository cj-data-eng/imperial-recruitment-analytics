locals {
  # Your GitHub username/repo. Change the owner if yours is different.
  github_repo = "cj-data-eng/imperial-recruitment-analytics"

  # The same state bucket name you pasted into the backend block.
  state_bucket = "terraform-state-prod-511454199223-eu-west-2-an"

  github_subject = "cj-data-eng@331987610/imperial-recruitment-analytics@1438266908"
}

# Look up the GitHub OIDC provider that already exists in the account.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# --- Who is allowed to use each role (the "trust policy") ---

# The plan role can only be used by pull_request runs from our repo.
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.github_subject}:pull_request",
        "repo:${local.github_repo}:pull_request",
      ]
    }
  }
}

# The apply role can only be used by runs on the main branch of our repo.
data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_subject}:ref:refs/heads/main"]
    }
  }
}

# --- What each role is allowed to do ---

# Both roles need to read (and lock) this project's Terraform state.
data "aws_iam_policy_document" "state_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/imperial-recruitment/*"]
  }
}

# The apply role can manage the project's bucket, Glue and Athena.
# It can only READ IAM, so CI can never change its own permissions.
# Changes to this file are applied from your laptop on purpose.
data "aws_iam_policy_document" "apply_permissions" {
  source_policy_documents = [data.aws_iam_policy_document.state_access.json]

  statement {
    sid       = "ManageProjectBucket"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.raw.arn, "${aws_s3_bucket.raw.arn}/*"]
  }

  statement {
    sid       = "ManageCatalogAndQueries"
    actions   = ["glue:*", "athena:*"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadIamForRefresh"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }
}

# --- The roles themselves ---

resource "aws_iam_role" "ci_plan" {
  name               = "imperial-recruitment-ci-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy_attachment" "ci_plan_read_only" {
  role       = aws_iam_role.ci_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "ci_plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.ci_plan.id
  policy = data.aws_iam_policy_document.state_access.json
}

resource "aws_iam_role" "ci_apply" {
  name               = "imperial-recruitment-ci-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

resource "aws_iam_role_policy" "ci_apply" {
  name   = "terraform-apply"
  role   = aws_iam_role.ci_apply.id
  policy = data.aws_iam_policy_document.apply_permissions.json
}