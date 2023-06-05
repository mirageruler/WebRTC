terraform {
  required_version = "~> 1.1" //Allow minor and patch version upgrade.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25" //Allow minor and patch version upgrade.
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.13"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.13.0" //Using specific version as provider is third party (non-hashicorp)
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.3"
    }
  }
}

terraform {
  backend "s3" {
    bucket                  = var.bucket
    key                     = "terraform.tfstate"
    region                  = var.region
    profile                 = var.profile //If not specific, default profile name will be used from .aws\credentials file.
    shared_credentials_file = "~/.aws/credentials"
    encrypt                 = true
    kms_key_id              = var.kms_key_id
    dynamodb_table          = var.kms_key
  }
}

//This is the region where current workloads are deployed --> primary region
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      terraform   = "true"
      environment = var.env_prefix
      region      = var.region
    }
  }
  profile                 = var.profile //If not specific, default profile name will be used from .aws\credentials file.
  shared_credentials_file = "~/.aws/credentials"
}
