# ABOUTME: Versões mínimas do Terraform e dos providers usados pelo laboratório.
# ABOUTME: Fixar aqui evita que uma máquina do grupo gere um plano diferente da outra.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "cicd-grupo-WJD"
      ManagedBy = "terraform"
      Course    = "CESAR School - CI/CD e Automação de Deployments"
    }
  }
}
