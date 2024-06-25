## Kasten namespace
resource "kubernetes_namespace" "kastenio" {
  depends_on = [module.eks,helm_release.aws-csi-eks]
  metadata {
    name = "kasten-io"
  }
}

## Kasten Helm
resource "helm_release" "k10" {
  depends_on = [module.eks,helm_release.aws-csi-eks,aws_iam_access_key.kasten,aws_iam_user_policy.kasten]  
  name = "k10"
  namespace = kubernetes_namespace.kastenio.metadata.0.name
  repository = "https://charts.kasten.io/"
  chart      = "k10"
  
  set {
    name  = "externalGateway.create"
    value = true
  }

  set {
    name  = "secrets.awsAccessKeyId"
    value = aws_iam_access_key.kasten.id
  }

  set {
    name  = "secrets.awsSecretAccessKey"
    value = aws_iam_access_key.kasten.secret
  }

  set {
    name  = "auth.tokenAuth.enabled"
    value = true
  } 

}

##  Creating authentication Token
resource "kubernetes_token_request_v1" "k10token" {
  depends_on = [helm_release.k10]

  metadata {
    name = "k10-k10"
    namespace = kubernetes_namespace.kastenio.metadata.0.name
  }
  spec {
    expiration_seconds = var.tokenexpirehours*3600
  }
}

## Getting Kasten LB Address
data "kubernetes_service_v1" "gateway-ext" {
  depends_on = [helm_release.k10]
  metadata {
    name = "gateway-ext"
    namespace = "kasten-io"
  }
}

## Accepting EULA
resource "kubernetes_config_map" "eula" {
  depends_on = [helm_release.k10]
  metadata {
    name = "k10-eula-info"
    namespace = "kasten-io"
  }
  data = {
    accepted = "true"
    company  = "Veeam"
    email = var.owner
  }
}


## Kasten AWS S3 Location Profile
resource "helm_release" "aws-s3-locprofile" {
  depends_on = [helm_release.k10]
  name = "${var.cluster_name}-aws-s3-locprofile"
  repository = "https://prcerda.github.io/Helm-Charts/"
  chart      = "aws-s3-locprofile"  
  
  set {
    name  = "bucketname"
    value = aws_s3_bucket.k10_s3_bucket.bucket
  }

  set {
    name  = "aws_access_key"
    value = aws_iam_access_key.kasten.id
  }

  set {
    name  = "aws_secret_access_key"
    value = aws_iam_access_key.kasten.secret
  }

  set {
    name  = "region"
    value = var.region
  }    
}

## Kasten K10 Config
resource "helm_release" "k10-config" {
  depends_on = [helm_release.k10]
  name = "${var.cluster_name}-k10-config"
  repository = "https://prcerda.github.io/Helm-Charts/"
  chart      = "k10-config"  
  
  set {
    name  = "bucketname"
    value = aws_s3_bucket.k10_s3_bucket.bucket
  }

  set {
    name  = "buckettype"
    value = "awss3"
  }
}