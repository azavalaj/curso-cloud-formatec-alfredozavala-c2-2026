variable "aws_region" {
  description = "AWS region supplied by the lab GitHub Actions environment."
  type        = string
}

variable "student_identity" {
  description = "Stable student identifier supplied by the lab GitHub Actions environment."
  type        = string

  validation {
    condition     = length(trimspace(var.student_identity)) > 0
    error_message = "student_identity must not be empty."
  }
}

variable "ec2_instance_profile_name" {
  description = "Existing EC2 instance profile created by the classroom IAM setup."
  type        = string
  default     = ""
}
