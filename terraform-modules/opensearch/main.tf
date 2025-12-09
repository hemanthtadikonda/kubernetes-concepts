resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "opensearchservice.amazonaws.com"
}

resource "aws_opensearch_domain" "pimcore_global" {
  domain_name = var.domain_name
  engine_version = "OpenSearch_3.1" # choose appropriate version; adjust as needed

  cluster_config {
    instance_type = var.instance_type
    instance_count = var.instance_count
    zone_awareness_enabled = var.zone_awareness_enabled
    zone_awareness_config {
      availability_zone_count = var.availability_zone_count
    }

    dedicated_master_enabled = true
    dedicated_master_type    = "t3.small.search"
    dedicated_master_count   = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
    # gp3 allows IOPS/throughput tuning if needed (optionally add iops and throughput)
    # iops       = 3000
    # throughput = 125
  }

  # VPC (no public access)
  vpc_options {
    subnet_ids = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  }

  access_policies = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "*" },
      "Action": "es:*",
      "Condition": {
        "IpAddress": { "aws:SourceIp": "10.0.0.0/16" }
      },
      "Resource": "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.domain_name}/*"
    }
  ]
}
POLICY

  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }
  tags = {
    Project = "Hemanth-Admin"
    Environment = "stage"
  }
}

data "aws_caller_identity" "current" {}
