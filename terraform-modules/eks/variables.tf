variable "region" {
  default = "us-east-1"
}
variable "cluster_name" {
  default = "Hemanth_pim_cluster_staging"
}

variable "project" {
  default = "Hemanthmiro_Admin"
}
variable "environment" {
  default = "staging"
}
variable "k8s_version" {
  default = "1.30"
}



variable "node_instance_type" { default = "t3.large" } //c5.9xlarge
variable "node_min" {  default = 2 }
variable "node_desired" {  default = 2 }
variable "node_max" {  default = 2 }

variable "ssh_key_name" { default = "my-eks-keypair" }
variable "fs_name" {default = "hemanth-staging-us-east1-efs"}
