resource "aws_iam_user" "kasten" {
  name = "k10user-${var.cluster_name}-${local.saString}"
  tags = {
    owner = var.owner
    activity = var.activity    
  }
}

resource "aws_iam_access_key" "kasten" {
  user = aws_iam_user.kasten.name
}

resource "aws_iam_user_policy" "kasten" {
  name = "k10policy-${var.cluster_name}-${local.saString}"
  user = aws_iam_user.kasten.name
  policy = jsonencode(
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CopySnapshot",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteTags",
                "ec2:DeleteVolume",
                "ec2:DescribeSnapshotAttribute",
                "ec2:ModifySnapshotAttribute",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeRegions",
                "ec2:DescribeSnapshots",
                "ec2:DescribeTags",
                "ec2:DescribeVolumeAttribute",
                "ec2:DescribeVolumesModifications",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ebs:ListSnapshotBlocks",
                "ebs:ListChangedBlocks",
                "ebs:GetSnapshotBlock"
            ],
            "Resource": "arn:aws:ec2:*::snapshot/*"
        },        
        {
            "Effect": "Allow",
            "Action": "ec2:DeleteSnapshot",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/name": "kasten__snapshot*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "ec2:DeleteSnapshot",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/Name": "Kasten: Snapshot*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "rds:CreateDBInstance",
                "rds:DeleteDBInstance",
                "rds:DescribeDBInstances",
                "rds:CreateDBSnapshot",
                "rds:DeleteDBSnapshot",
                "rds:DescribeDBSnapshots",
                "rds:DescribeDBSnapshotAttributes",
                "rds:CreateDBCluster",
                "rds:DescribeDBClusters",
                "rds:DeleteDBCluster",                 
                "rds:CreateDBClusterSnapshot",
                "rds:DeleteDBClusterSnapshot",
                "rds:DescribeDBClusterSnapshots",
                "rds:DescribeDBClusterSnapshotAttributes",
                "rds:RestoreDBInstanceFromDBSnapshot",
                "rds:RestoreDBClusterFromSnapshot"
            ],
            "Resource": "*"
        },        
        {
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:PutBucketPolicy",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:DeleteBucketPolicy",
                "s3:GetBucketLocation",
                "s3:GetBucketPolicy"
            ],
            "Resource": "*"
        }]
    })
}    