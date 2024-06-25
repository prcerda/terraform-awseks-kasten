variable "region" {
  description = "AWS region"
  type        = string
}

variable "owner" {
  type = string
}

variable "activity" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "k8sversion" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_private_init" {
  type = number
}

variable "subnet_public_init" {
  type = number
}

variable "tokenexpirehours" {
  type = number
  default = 36
}