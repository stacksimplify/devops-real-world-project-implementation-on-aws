# Install Secrets Store CSI Driver (Kubernetes SIGs)
resource "helm_release" "secrets_store_csi_driver" {
  depends_on = [
    aws_eks_addon.podidentity,
    aws_eks_node_group.private_nodes
  ]

  name       = "csi-secrets-store"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"

  # Note: tokenRequests is required for EKS Pod Identity authentication when
  # the CSI driver is installed separately (not bundled via the AWS provider chart).
  # Audience "pods.eks.amazonaws.com" is for EKS Pod Identity. We do not configure
  # the IRSA audience (sts.amazonaws.com) because this course uses Pod Identity only.
  set = [
    {
      name  = "syncSecret.enabled"
      value = "true"
    },
    {
      name  = "tokenRequests[0].audience"
      value = "pods.eks.amazonaws.com"
    },
  ]

  # Wait until all pods are ready
  wait            = true
  timeout         = 600
  cleanup_on_fail = true
}

# Outputs

output "helm_secrets_store_csi_driver_metadata" {
  description = "Metadata for the Secrets Store CSI Driver Helm release"
  value       = helm_release.secrets_store_csi_driver.metadata
}
