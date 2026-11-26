terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend distant recommandé en équipe (state chiffré + verrouillage).
  # Décommenter après avoir créé le bucket de state.
  # backend "s3" {
  #   bucket       = "mon-bucket-tfstate"
  #   key          = "secure-baseline/terraform.tfstate"
  #   region       = "eu-west-3"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Owner     = var.owner
    }
  }
}
