variable "region" { default = "us-east-1" }
variable "cluster_name" { default = "Hemanth-pim-cluster-staging" }
variable "project" {  default = "Hemanthmiro-Admin" }
variable "environment" { default = "staging" }
variable "k8s_version" {  default = "1.30" }

variable "vpc_cidr" {  default = "10.0.0.0/16" }
variable "public_subnet_cidrs" {  default = ["10.0.0.0/24","10.0.1.0/24"] }
variable "private_subnet_cidrs" {  default = ["10.0.10.0/24","10.0.11.0/24"] }

variable "node_instance_type" { default = "t3.large" } //c5.9xlarge
variable "node_min" {  default = 1 }
variable "node_desired" {  default = 1 }
variable "node_max" {  default = 2 }

variable "ssh_key_name" { default = "my-eks-keypair" }
variable "fs_name" {default = "heamnth-staging-us-east1-efs"}
