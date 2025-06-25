terraform {
  required_version = ">=1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "aws" {
  region = var.region
}
