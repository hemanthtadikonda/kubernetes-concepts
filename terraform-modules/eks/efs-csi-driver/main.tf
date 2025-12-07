# data to read cluster info (OIDC issuer)
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

# ensure OIDC provider exists beforehand (create if needed outside or via aws_iam_openid_connect_provider)

module "irsa_efs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "CSI-Role-${var.cluster_name}"
  provider_url                  = replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")
  role_policy_arns              = [
    "arn:aws:iam::aws:policy/AmazonEFSCSIDriverPolicy"  # prefer this managed policy
  ]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:efs-csi-controller-sa"
  ]

  tags = {
    managed-by = "terraform"
    component  = "efs-csi"
  }
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-efs-csi-driver"
  service_account_role_arn    = module.irsa_efs_csi.iam_role_arn
  resolve_conflicts_on_update = "PRESERVE"

  # optional: pin the addon version once tested in staging
  # addon_version = "v1.xx.x-eksbuild.y"

  tags = {
    eks_addon = "efs-csi"
    managed   = "terraform"
  }

  # ensure we don't install while conflicting helm release exists
  depends_on = [module.irsa_efs_csi]
}

//Important: Ensure there is no self‑managed EFS CSI driver running (e.g. from previous Helm install). Uninstall it first before applying the addon
//After apply, wait until the addon becomes active:
//aws eks wait addon-active --cluster-name <CLUSTER_NAME> --addon-name aws-efs-csi-driver
//aws eks describe-addon --cluster-name <cluster_name> --addon-name aws-efs-csi-driver