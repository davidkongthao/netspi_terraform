provider "aws" {
    region              = var.aws_default_region
    access_key          = var.access_key
    secret_key          = var.secret_key

    default_tags {
        tags = {
            SourceControl   = "Terraform"
            Purpose         = "NetSPI_Challenge"
        }
    }
}

terraform {
    required_version        = ">=1.3.7"
    required_providers {
        aws = {
            source          = "hashicorp/aws"
            version         = "~> 4.56.0"
        }
        tls = {
            source          = "hashicorp/tls"
            version         = "~> 4.0.4"
        }
    }
}
