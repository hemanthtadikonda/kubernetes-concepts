terraform {
  backend "s3" {
    bucket = "tad-state"
    key    = "helix/dev/ecr/statefile"
    region = "us-east-1"
  }
}