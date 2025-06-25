variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
  default     = "development"
}

variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "zone1" {
  description = "The first availability zone."
  type        = string
  default     = "us-east-1a"
}

variable "zone2" {
  description = "The second availability zone."
  type        = string
  default     = "us-east-1b"
}

variable "eks_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "bilarn_cluster1"
}

variable "eks_version" {
  description = "The version of the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "key_pair_name" {
  description = "The name of the AWS key pair to use for SSH access."
  type        = string
  default     = "ec2-aws-key"
}

variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
}



