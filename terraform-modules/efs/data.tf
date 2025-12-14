data "aws_vpc" "helix_vpc" {
  filter {
    name   = "tag:Name"
    values = ["default_vpc"]  # Replace with your actual VPC Name tag
  }
}
data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.helix_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]   # or Tier=private (preferred)
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private_subnets.ids)
  id       = each.value
}


