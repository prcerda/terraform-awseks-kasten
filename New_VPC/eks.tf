resource "time_static" "epoch" {}
locals {
  saString = "${time_static.epoch.unix}"
}

provider "aws" {
  region = var.region
}


# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_int_name = "eks-${var.cluster_name}-${local.saString}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)  
}

## Create VPC resources

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "vpc-${var.cluster_name}-${local.saString}"

  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false  
  enable_dns_hostnames   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    owner = var.owner
    activity = var.activity    
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    owner = var.owner
    activity = var.activity    
  }

  tags = {
    owner = var.owner
    activity = var.activity      
  }
}



## AWS VPC Endpoint for AWS S3
resource "aws_vpc_endpoint" "veeam_aws_s3_endpoint" {
  vpc_id            = module.vpc.vpc_id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.region}.s3"
  route_table_ids   = flatten([module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
  tags = {
    Name = "s3-endpoint-${var.cluster_name}-${local.saString}"
    owner = var.owner
    activity = var.activity      
  }  
}

### S3 bucket to store K10 backups

resource "aws_s3_bucket" "k10_s3_bucket" {
  bucket = "s3-${var.cluster_name}-${local.saString}"
  force_destroy = true
  # IMPORTANT! The bucket and all contents will be deleted upon running a `terraform destory` command
  tags = {
	owner = var.owner
	activity = var.activity
  }
}

resource "aws_s3_bucket_public_access_block" "k10_aws_bucket_public_access_block" {
  bucket = aws_s3_bucket.k10_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "k10_aws_bucket_ownership_controls" {
  bucket = aws_s3_bucket.k10_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

## AWS EKS Cluster with VPC Resources created
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_int_name
  cluster_version = "1.29"

  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  cluster_addons = {
    snapshot-controller = {}
    aws-ebs-csi-driver = {
      most_recent = true
    }
  } 

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"
      ami_type       = "AL2_x86_64"
      instance_types = ["m5.large"]      
      min_size     = 2
      max_size     = 4
      desired_size = 3
      iam_role_additional_policies = { 
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" 
      } 
    }
  }

  tags = {
    owner = var.owner
    activity = var.activity      
  }    
}

## CSI StorageClass and VolumeSnapshotClass
resource "helm_release" "aws-csi-eks" {
  depends_on = [module.eks]
  name = "${var.cluster_name}-aws-csi-eks"
  repository = "https://prcerda.github.io/Helm-Charts/"
  chart      = "aws-csi-eks"  
}


resource "kubernetes_annotations" "gp2" {
  depends_on = [module.eks,helm_release.aws-csi-eks]
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true
}