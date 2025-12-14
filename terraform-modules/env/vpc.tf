module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = ">= 6.5.0"

  name = "helix-dev-vpc" // Naming convention is project-env-resource
  cidr = "10.105.82.0/23"

  secondary_cidr_blocks = [
    "100.66.0.0/21"
  ]

  azs = ["us-east-1a", "us-east-1b"]

  private_subnets = [
    "100.66.0.0/22",   # AZ: us-east-1a
    "100.66.4.0/22"    # AZ: us-east-1b
  ]

  # KEEP all 6 public subnets — module will create them in round-robin across AZs
  public_subnets = [
    "10.105.82.0/26",      # index 0 -> AZ1  <<< we want NAT here
    "10.105.82.64/26",     # index 1 -> AZ2  <<< and NAT here
    "10.105.82.128/26",    # index 2 -> AZ1
    "10.105.82.192/26",    # index 3 -> AZ2
    "10.105.83.0/26",      # index 4 -> AZ1
    "10.105.83.64/26"      # index 5 -> AZ2
  ]

  enable_nat_gateway = false //true to have module create NATs in all public subnets
  enable_vpn_gateway = false //true to have module create a VPN Gateway

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}
## create a Transit Gateway
module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = ">= 3.0.2"

  name        = "helix-dev-tgw"
  description = "TGW shared with several other AWS accounts"

  enable_auto_accept_shared_attachments = true

  amazon_side_asn = 65000
  vpc_attachments = {
    vpc = {
      vpc_id       = module.vpc.vpc_id
      subnet_ids   = module.vpc.private_subnets
      dns_support  = true
      ipv6_support = true
    }
  }
  tags = {
    Project   = "helix-dev"
    Name      = "helix-dev-vpc-tgw-attach-01"
  }
}

# MANUAL NAT Gateways (2) — only in the two chosen public subnets (indices 0 & 1)
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "helix-dev-nat-eip-${count.index}"
  }
}
# Create 2 NAT Gateways in the public subnets you choose
# Suppose you want NATs in public_subnets indices 0 and 1
resource "aws_nat_gateway" "vpc_helix_dev" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = element(module.vpc.public_subnets, count.index)  # use 0 and 1

  tags = {
    Name = "manual-nat-${count.index}"
  }

  depends_on = [module.vpc]
}
# Route private subnets to NATs
resource "aws_route" "private_to_nat" {
  count = length(module.vpc.private_subnets)

  route_table_id         = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"

  # Map private subnets to NATs in a round-robin way (modulo)
  nat_gateway_id = aws_nat_gateway.vpc_helix_dev[count.index % length(aws_nat_gateway.vpc_helix_dev)].id
}
