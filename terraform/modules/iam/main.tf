locals {
  service_statements = [
    for svc in var.trusted_service_principals : {
      Effect    = "Allow"
      Principal = { Service = svc }
      Action    = "sts:AssumeRole"
    }
  ]

  account_statements = [
    for acct in var.trusted_account_ids : {
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${acct}:root" }
      Action    = "sts:AssumeRole"
    }
  ]

  principal_statements = [
    for arn in var.trusted_principal_arns : {
      Effect    = "Allow"
      Principal = { AWS = arn }
      Action    = "sts:AssumeRole"
    }
  ]

  trust_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = concat(local.service_statements, local.account_statements, local.principal_statements)
  })
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = local.trust_policy
  tags               = var.tags
}