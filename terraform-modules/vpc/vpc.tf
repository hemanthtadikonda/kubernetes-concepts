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

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  # Public subnets (ALB, NAT Gateway, Bastion)
  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24"
  ]

  # Application subnets (EKS nodes, EC2 apps)
  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]

  # Database subnets (RDS, Aurora)
  database_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24",
    "10.0.13.0/24"
  ]

  # NAT Gateway for private/app subnets
  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true

  # DB subnet group & routing
  create_database_subnet_group = true
  create_database_subnet_route_table = true

  # Optional but recommended
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
