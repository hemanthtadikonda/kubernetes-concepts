terraform {
  backend "s3" {
    bucket = "tad-state"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}