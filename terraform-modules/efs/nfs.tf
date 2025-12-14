resource "aws_efs_file_system" "helix_efs" {
  creation_token = "helix-efs-token"
  encrypted      = true
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Name        = "helix-dev-efs"
    Project     = "helix"
    Env         = "dev"
    Terraform   = "true"
  }
}
resource "aws_efs_access_point" "helix_ap" {
  file_system_id = aws_efs_file_system.helix_efs.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/helix_dev_data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "750"
    }
  }
}
resource "aws_security_group" "efs_sg" {
  name        = "helix-efs-sg"
  description = "Allow NFS access to EFS"
  vpc_id      = data.aws_vpc.helix_vpc.id  # Reference your VPC ID here

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [for s in data.aws_subnet.private : s.cidr_block] # e.g., private subnet CIDRs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_mount_target" "mt" {
  count           = length(data.aws_subnets.private_subnets.ids)
  file_system_id  = aws_efs_file_system.helix_efs.id
  subnet_id       = data.aws_subnets.private_subnets.ids[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

