output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "kubeconfig" {
  description = "Configure kubeconfig to access this cluster"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "s3_bucket_name" {
  description = "AWS S3 Bucket name"
  value = aws_s3_bucket.k10_s3_bucket.bucket
}

output "k10token" {
  value = nonsensitive(kubernetes_token_request_v1.k10token.token)
}

output "k10url" {
  description = "Kasten K10 URL"
  value = "http://${data.kubernetes_service_v1.gateway-ext.status.0.load_balancer.0.ingress.0.hostname}/k10/"
}

output "demoapp_url" {
  description = "Demo App URL"
  value = "http://${kubernetes_service_v1.stock-demo-svc.status.0.load_balancer.0.ingress.0.hostname}"
}