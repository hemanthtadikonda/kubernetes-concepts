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
