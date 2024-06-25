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

variable "vpc_cidr" {
  type = string
}

variable "tokenexpirehours" {
  type = number
  default = 36
}