variable "region" { default = "us-east-1" }
variable "cluster_name" { default = "Hemanth-pim-cluster-staging" }
variable "project" { type = string, default = "Hemanthmiro-Admin" }
variable "environment" { type = string, default = "staging" }
variable "k8s_version" { type = string, default = "1.32" }

variable "vpc_cidr" { type = string, default = "10.0.0.0/16" }
variable "public_subnet_cidrs" { type = list(string), default = ["10.0.0.0/24","10.0.1.0/24"] }
variable "private_subnet_cidrs" { type = list(string), default = ["10.0.10.0/24","10.0.11.0/24"] }

variable "node_instance_type" { type = string, default = "t3.large" } //c5.9xlarge
variable "node_min" { type = number, default = 1 }
variable "node_desired" { type = number, default = 1 }
variable "node_max" { type = number, default = 2 }

variable "ssh_key_name" { type = string, default = "hemaN.vir" }
variable "fs_name" {}
