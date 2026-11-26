data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# ---------------------------------------------------------------------------
# Chiffrement : une clé KMS gérée par le client, rotation automatique
# ---------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "${var.project} - chiffrement des logs et du stockage"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.main.key_id
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "CloudTrailEncrypt"
    actions   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${local.partition}:cloudtrail:*:${local.account_id}:trail/*"]
    }
  }

  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${var.region}:${local.account_id}:*"]
    }
  }

  statement {
    sid       = "SNSFromAWSServices"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "cloudwatch.amazonaws.com", "budgets.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# Identité : politique de mots de passe forte (CIS AWS 1.8 - 1.9)
# ---------------------------------------------------------------------------
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
}

# Détecte les ressources partagées publiquement ou avec un compte externe
resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "${var.project}-analyzer"
  type          = "ACCOUNT"
}

# ---------------------------------------------------------------------------
# Stockage : blocage de l'accès public S3 au niveau du compte (CIS 2.1.4)
# ---------------------------------------------------------------------------
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# ---------------------------------------------------------------------------
# Réseau
# ---------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name               = var.project
  cidr               = var.vpc_cidr
  az_count           = var.az_count
  kms_key_arn        = aws_kms_key.main.arn
  log_retention_days = var.log_retention_days
}
