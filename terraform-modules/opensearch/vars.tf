variable "region" {
  type    = string
  default = "us-east-1"
}

variable "domain_name" {
  type    = string
  default = "im-es-global-stage"
}

variable "instance_type" {
  type    = string
  default = "t3.small.search" //"m5.large.search"
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "zone_awareness_enabled" {
  type    = bool
  default = true
}


variable "availability_zone_count" {
  type    = number
  default = 2
}

variable "ebs_volume_size" {
  type    = number
  default = 30
  description = "GiB"
}

variable "ebs_volume_type" {
  type    = string
  default = "gp3"
}

variable "vpc_subnet_ids" {
  type    = list(string)
  default = ["subnet-0875410ab2506d634","subnet-0a0966e1ba6be380a",]
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = ["sg-0baa986d8ebb5eeda"]
}

## Optional: S3 bucket for manual snapshots (if you want manual backups stored in your S3)
#variable "snapshot_bucket_name" {
#  type    = string
#  default = ""
#}
