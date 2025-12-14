module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs              =  ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets  =  ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   =  ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets =  ["10.0.11.0/24", "10.0.12.0/24","10.0.13.0/24" ]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

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
