provider "aws" {
  region = var.region
}

terraform {

  backend "s3" {
    bucket ="terraform-2023"
    key    = "terraform"
    region = "us-east-2"
  }
}