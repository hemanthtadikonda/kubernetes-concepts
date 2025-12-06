terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_ecr_repository" "example" {
  for_each = toest([
    "Hemanth-talent-dev",
    "Hemanth-talent-prod" ,
  ])
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
  tags = {
    ManagedBy = "terraform"
    Project   = "Hemanthmiro-Admin"
    Env       = var.environment
  }

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

