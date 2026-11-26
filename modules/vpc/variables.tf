variable "name" {
  description = "Préfixe des noms de ressources"
  type        = string
}

variable "cidr" {
  description = "CIDR du VPC"
  type        = string
}

variable "az_count" {
  description = "Nombre de zones de disponibilité"
  type        = number
  default     = 2
}

variable "kms_key_arn" {
  description = "Clé KMS pour chiffrer les flow logs"
  type        = string
}

variable "log_retention_days" {
  description = "Conservation des flow logs"
  type        = number
  default     = 365
}
