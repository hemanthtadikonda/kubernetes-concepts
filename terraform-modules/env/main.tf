module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "usaw-vpc-pim-prd-01"
  cidr = "10.105.82.0/23"
  secondary_cidr_blocks = [
    "100.66.0.0/21"         # Secondary CIDR
  ]

  azs             = ["us-east-1a" , "us-east-1b"]
  private_subnets = ["100.66.0.0/22", "100.66.4.0/22"]
  public_subnets  = ["10.105.82.0/25","10.105.82.128/25","10.105.83.64/27","10.105.83.96/27","10.105.83.0/27","10.105.83.32/27"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "2.9.0"

  name        = "usaw-vpc-pim-prd-tgw"
  description = "Transit Gateway for im-core-prod"

  amazon_side_asn = 65000

  share_tgw = false


  tags = {
    Environment = "prod"
  }
}
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach" {
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets   # attachment always uses private subnets

  dns_support  = "enable"
  ipv6_support = "disable"

  tags = {
    Name = "prod-vpc-tgw-attach-01"
  }
}



provider "aws" {
  region = "us-east-1"
}
#
#############################
## VPC module: create 6 public subnets
## but disable automatic NAT creation
#############################
#module "vpc" {
#  source = "terraform-aws-modules/vpc/aws"
#  version = ">= 2.77.0"
#
#  name = "usaw-vpc-pim-prd-01"
#  cidr = "10.105.82.0/23"
#
#  secondary_cidr_blocks = [
#    "100.66.0.0/21"
#  ]
#
#  azs = ["us-east-1a", "us-east-1b"]
#
#  private_subnets = [
#    "100.66.0.0/22",   # AZ: us-east-1a
#    "100.66.4.0/22"    # AZ: us-east-1b
#  ]
#
#  # KEEP all 6 public subnets — module will create them in round-robin across AZs
#  public_subnets = [
#    "10.105.82.0/25",     # index 0 -> AZ1
#    "10.105.82.128/25",   # index 1 -> AZ2
#    "10.105.83.64/27",    # index 2 -> AZ1
#    "10.105.83.96/27",    # index 3 -> AZ2
#    "10.105.83.0/27",     # index 4 -> AZ1  <<< we want NAT here
#    "10.105.83.32/27"     # index 5 -> AZ2  <<< and NAT here
#  ]
#
#  # Disable module-created NAT Gateways so we can create NATs manually where we want
#  enable_nat_gateway = false
#  enable_vpn_gateway = false
#
#  tags = {
#    Terraform   = "true"
#    Environment = "prod"
#  }
#}
#
#########################################
## Transit Gateway module
#########################################
#module "tgw" {
#  source  = "terraform-aws-modules/transit-gateway/aws"
#  version = "2.9.0"
#
#  name        = "usaw-vpc-pim-prd-tgw"
#  description = "Transit Gateway for im-core-prod"
#
#  amazon_side_asn = 65000
#  share_tgw       = false
#
#  tags = {
#    Environment = "prod"
#  }
#}

########################################
# TGW VPC Attachment (private subnets only)
########################################
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach" {
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.vpc.vpc_id

  # Attach using the private subnets created by the module
  subnet_ids = module.vpc.private_subnets

  dns_support  = "enable"
  ipv6_support = "disable"

  tags = {
    Name = "prod-vpc-tgw-attach-01"
  }
}

########################################
# MANUAL NAT Gateways (2) — only in the two chosen public subnets (indices 4 & 5)
########################################

# Create 2 Elastic IPs (one per NAT)
resource "aws_eip" "nat" {
  count = 2
  vpc   = true
  tags = {
    Name = "nat-eip-${count.index}"
  }
}

# Create 2 NAT Gateways in the public subnets we picked.
# We select the subnet ids using the same order as `module.vpc.public_subnets`.
# Indices: 4 and 5 correspond to "10.105.83.0/27" and "10.105.83.32/27".
resource "aws_nat_gateway" "this" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id

  # Map count.index 0 -> public_subnet index 4
  #              1 -> public_subnet index 5
  subnet_id = element(module.vpc.public_subnets, 4 + count.index)

  tags = {
    Name = "manual-nat-${count.index}"
  }

  depends_on = [module.vpc]  # ensure subnets exist first
}

########################################
# Add routes for private route tables to use the NATs (1 NAT per private RT)
########################################

# For each private route table (one per private subnet/AZ) create a 0.0.0.0/0 route to the NAT in the same index (AZ)
resource "aws_route" "private_to_nat" {
  count = length(module.vpc.private_route_table_ids)

  route_table_id         = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"

  # Use the NAT gateway created in the corresponding AZ (count.index -> nat index)
  # We created NATs at indices [4,5] of public_subnets but aws_nat_gateway.this[*].id list is 0..1 (AZ order)
  # We assumed private subnets list order matches NATs order (module maps lists to AZs consistently).
  nat_gateway_id = aws_nat_gateway.this[count.index].id

  depends_on = [aws_nat_gateway.this]
}
