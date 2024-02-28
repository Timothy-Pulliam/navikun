variable "app_name" {
  type        = string
  description = "Name of Elastic Container Registry"
  default     = "myapp"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "s3_force_destroy" {
  type        = bool
  description = "Delete S3 bucket contents when deleting the bucket"
  default     = false
}
