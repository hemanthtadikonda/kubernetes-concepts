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
  default_route_table_association = true
  default_route_table_propagation = true

  tags = {
    Environment = "prod"
  }
}
module "tgw_vpc_attachment" {
  source  = "terraform-aws-modules/transit-gateway/aws//modules/tgw-vpc-attachment"
  version = "2.9.0"

  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets

  appliance_mode_support = false
  dns_support            = true

  tags = {
    Name = "im-core-prod-tgw-attachment"
  }
}
