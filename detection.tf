# ---------------------------------------------------------------------------
# Détection & alerting
# ---------------------------------------------------------------------------
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_sns_topic" "security_alerts" {
  name              = "${var.project}-security-alerts"
  kms_master_key_id = aws_kms_key.main.id
}

data "aws_iam_policy_document" "sns_publish" {
  statement {
    sid       = "AllowAWSServicesPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "cloudwatch.amazonaws.com", "budgets.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "security_alerts" {
  arn    = aws_sns_topic.security_alerts.arn
  policy = data.aws_iam_policy_document.sns_publish.json
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# GuardDuty : findings de sévérité >= 7 (high) envoyés par e-mail
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${var.project}-guardduty-high"
  description = "Findings GuardDuty de sévérité haute"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail        = { severity = [{ numeric = [">=", 7] }] }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule = aws_cloudwatch_event_rule.guardduty_high.name
  arn  = aws_sns_topic.security_alerts.arn
}

# ---------------------------------------------------------------------------
# Alarmes CIS AWS Foundations (section 4) à partir des logs CloudTrail
# ---------------------------------------------------------------------------
locals {
  cis_alarms = {
    root-account-usage = {
      description = "Utilisation du compte root (CIS 4.3)"
      pattern     = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
    }
    console-login-without-mfa = {
      description = "Connexion console sans MFA (CIS 4.2)"
      pattern     = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.responseElements.ConsoleLogin = \"Success\") }"
    }
    unauthorized-api-calls = {
      description = "Appels API refusés (CIS 4.1)"
      pattern     = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"
    }
    iam-policy-changes = {
      description = "Modification de politiques IAM (CIS 4.4)"
      pattern     = "{ ($.eventSource = \"iam.amazonaws.com\") && (($.eventName = \"PutUserPolicy\") || ($.eventName = \"AttachUserPolicy\") || ($.eventName = \"CreatePolicy\") || ($.eventName = \"DeletePolicy\") || ($.eventName = \"AttachRolePolicy\") || ($.eventName = \"PutRolePolicy\")) }"
    }
    cloudtrail-config-changes = {
      description = "Modification / arrêt de CloudTrail (CIS 4.5)"
      pattern     = "{ ($.eventName = \"StopLogging\") || ($.eventName = \"DeleteTrail\") || ($.eventName = \"UpdateTrail\") }"
    }
    security-group-changes = {
      description = "Modification de security groups (CIS 4.10)"
      pattern     = "{ ($.eventName = \"AuthorizeSecurityGroupIngress\") || ($.eventName = \"RevokeSecurityGroupIngress\") || ($.eventName = \"CreateSecurityGroup\") || ($.eventName = \"DeleteSecurityGroup\") }"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "cis" {
  for_each       = local.cis_alarms
  name           = each.key
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = each.value.pattern

  metric_transformation {
    name      = each.key
    namespace = "CISBenchmark"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "cis" {
  for_each            = local.cis_alarms
  alarm_name          = "${var.project}-${each.key}"
  alarm_description   = each.value.description
  namespace           = "CISBenchmark"
  metric_name         = aws_cloudwatch_log_metric_filter.cis[each.key].metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# ---------------------------------------------------------------------------
# FinOps : alerte si le budget mensuel est dépassé (évite les mauvaises surprises)
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.security_alerts.arn]
  }
}
