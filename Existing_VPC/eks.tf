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

## Get existing VPC data
data "aws_vpc" "aws_vpc_custom" {
  id = var.vpc_id
}

## Create public subnets
resource "aws_subnet" "public" {
  for_each  = toset(local.azs)
  vpc_id    = data.aws_vpc.aws_vpc_custom.id
  cidr_block = cidrsubnet(data.aws_vpc.aws_vpc_custom.cidr_block, 8, index(local.azs, each.value)+var.subnet_public_init)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.cluster_name}-external-${each.value}"
    "kubernetes.io/role/elb" = 1
    owner = var.owner
    activity = var.activity    
  }
}

## Get Internet Gateway Data
data "aws_internet_gateway" "igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.aws_vpc_custom.id]
  }
}

## Create Routing Tables public subnet
resource "aws_route_table" "ext-routes" {
  vpc_id = data.aws_vpc.aws_vpc_custom.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.igw.id
  }

  tags = {
    Name = "external-routes-${var.cluster_name}-${local.saString}"
    owner = var.owner
    activity = var.activity      
  }
}

## Associate Route Tables with Subnets
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  route_table_id = aws_route_table.ext-routes.id
  subnet_id      = each.value.id
}


## Create private subnets
resource "aws_subnet" "private" {
  for_each  = toset(local.azs)
  vpc_id    = data.aws_vpc.aws_vpc_custom.id
  cidr_block = cidrsubnet(data.aws_vpc.aws_vpc_custom.cidr_block, 8, index(local.azs, each.value)+var.subnet_private_init) 
  tags = {
    Name = "${var.cluster_name}-internal-${each.value}"
    "kubernetes.io/role/internal-elb" = 1
    owner = var.owner
    activity = var.activity    
  }
}

## Get NAT Gateway Data
resource "aws_eip" "natgw" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw.id
  subnet_id     = aws_subnet.public[keys(aws_subnet.public)[0]].id

  tags = {
    Name = "natgw-${var.cluster_name}-${local.saString}"
    owner = var.owner
    activity = var.activity  
  }
}

## Create Routing Tables private subnet
resource "aws_route_table" "int-routes" {
  vpc_id = data.aws_vpc.aws_vpc_custom.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }  
  tags = {
    Name = "internal-routes--${var.cluster_name}-${local.saString}"
    owner = var.owner
    activity = var.activity      
  }
}

## Associate Route Tables with Subnets
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  route_table_id = aws_route_table.int-routes.id
  subnet_id      = each.value.id
}

## AWS VPC Endpoint for AWS S3
resource "aws_vpc_endpoint" "veeam_aws_s3_endpoint" {
  vpc_id            = data.aws_vpc.aws_vpc_custom.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.region}.s3"
  route_table_ids   = [aws_route_table.ext-routes.id,aws_route_table.int-routes.id]
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

  vpc_id     = data.aws_vpc.aws_vpc_custom.id
  subnet_ids = [for s in aws_subnet.private : s.id]
  control_plane_subnet_ids = [for k in aws_subnet.public : k.id]

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