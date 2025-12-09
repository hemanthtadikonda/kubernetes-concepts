module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "usaw-vpc-pim-prd-01"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a" , "us-east-1b"]
  private_subnets = ["10.0.1.0/24" , "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

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

  amazon_side_asn = 64512

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
