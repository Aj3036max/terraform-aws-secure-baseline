variable "region" {
  description = "Région AWS principale"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project" {
  description = "Préfixe utilisé pour nommer les ressources"
  type        = string
  default     = "secure-baseline"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project))
    error_message = "project : 3-20 caractères, minuscules, chiffres et tirets."
  }
}

variable "owner" {
  description = "Propriétaire (tag)"
  type        = string
  default     = "Aj3036max"
}

variable "vpc_cidr" {
  description = "Plage CIDR du VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Nombre de zones de disponibilité"
  type        = number
  default     = 2
}

variable "alert_email" {
  description = "E-mail qui reçoit les alertes sécurité et budget (laisser vide pour désactiver)"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Budget mensuel maximum avant alerte"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "Durée de conservation des logs (CloudWatch)"
  type        = number
  default     = 365
}
