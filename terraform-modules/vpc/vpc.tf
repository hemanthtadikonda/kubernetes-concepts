module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs              =  ["us-east-1a", "us-east-1b" ]
  private_subnets  =  ["10.0.1.0/24", "10.0.2.0/24" ]
  public_subnets   =  ["10.0.101.0/24", "10.0.102.0/24" ]
  database_subnets =  ["10.0.11.0/24", "10.0.12.0/24" ]

  enable_nat_gateway = true
  one_nat_gateway_per_az = true
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
