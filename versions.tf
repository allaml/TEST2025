
# Backendend S3 and DynamoDB 

terraform {
  # backend "s3" {
  #   bucket = "hoag-netappfsx"
  #   key            = "hoag-prod-tf-state/terraform.tfstate"
  #   # key            = "hoag/terraform.tfstate"
  #   dynamodb_table = "terraform_locks"
  #   region         = "us-east-2"
  #   profile        = "default"
  # }


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.25.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}


# Error: │ Error: error creating FSx ONTAP File System: BadRequest: Exactly 1 subnet IDs are required for SINGLE_AZ_1.aws_fsx_ontap_file_system incorrectly requires two subnet ids when used with single AZ
# Fix: https://github.com/hashicorp/terraform-provider-aws/issues/25339
