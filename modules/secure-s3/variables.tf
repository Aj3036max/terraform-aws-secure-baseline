variable "name" {
  description = "Nom du bucket (unique au niveau mondial)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la clé KMS utilisée pour le chiffrement"
  type        = string
}

variable "expiration_days" {
  description = "Suppression des objets après N jours"
  type        = number
  default     = 365
}

variable "extra_policy_doc" {
  description = "Document de politique JSON additionnel fusionné avec la politique TLS-only"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Autoriser la suppression du bucket non vide (à éviter en prod)"
  type        = bool
  default     = false
}
