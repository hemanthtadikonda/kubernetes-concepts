output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_name" { value = module.eks.cluster_id }
output "efs_id" { value = aws_efs_file_system.pimcore.id }