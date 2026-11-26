output "vpc_id" {
  description = "ID du VPC créé"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Sous-réseaux privés (pour les workloads)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Sous-réseaux publics (pour les load balancers uniquement)"
  value       = module.vpc.public_subnet_ids
}

output "cloudtrail_bucket" {
  description = "Bucket S3 qui stocke les logs CloudTrail"
  value       = module.cloudtrail_bucket.id
}

output "kms_key_arn" {
  description = "Clé KMS principale"
  value       = aws_kms_key.main.arn
}

output "security_alerts_topic" {
  description = "Topic SNS des alertes sécurité"
  value       = aws_sns_topic.security_alerts.arn
}
