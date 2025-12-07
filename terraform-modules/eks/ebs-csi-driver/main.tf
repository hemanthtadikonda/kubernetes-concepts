data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

module "irsa_ebs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "EBS‑CSI‑Role-${var.cluster_name}"
  provider_url                  = replace(data.aws_eks_cluster.eks.identity[ 0 ].oidc[ 0 ].issuer ,"https://" ,"")
  role_policy_arns              = [ "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" ]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:ebs-csi-controller-sa"
  ]

  tags = {
    "managed-by" = "terraform"
    "component"  = "ebs-csi"
  }
}
# tf/ebs_csi_addon.tf
resource "aws_eks_addon" "ebs_csi" {
  cluster_name              = var.cluster_name
  addon_name                = "aws-ebs-csi-driver"
  service_account_role_arn  = module.irsa_ebs_csi.iam_role_arn
  # If you want Terraform to preserve existing settings on updates:
  resolve_conflicts_on_update = "PRESERVE"

  # Optionally: specify a version compatible with your cluster.
  # addon_version = "v1.19.0-eksbuild.1"

  tags = {
    "eks_addon" = "ebs-csi"
    "managed"   = "terraform"
  }
}

//Important: Ensure there is no self‑managed EBS CSI driver running (e.g. from previous Helm install). Uninstall it first before applying the addon
//After apply, wait until the addon becomes active:
//aws eks wait addon-active --cluster-name <CLUSTER_NAME> --addon-name aws-ebs-csi-driver
//aws eks describe-addon --cluster-name <cluster_name> --addon-name aws-ebs-csi-driver