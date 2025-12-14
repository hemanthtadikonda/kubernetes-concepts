data "aws_vpc" "helix_vpc" {
  filter {
    name   = "tag:Name"
    values = ["default_vpc"]  # Replace with your actual VPC Name tag
  }
}
data "aws_subnet_ids" "private_subnets" {
  vpc_id = data.aws_vpc.helix_vpc.id

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}
data "aws_subnet" "private" {
  for_each = toset(data.aws_subnet_ids.private_subnets.ids)
  id       = each.value
}


