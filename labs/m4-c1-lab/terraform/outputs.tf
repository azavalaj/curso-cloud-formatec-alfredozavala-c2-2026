output "vpc_id" {
  description = "Lab VPC ID."
  value       = aws_vpc.this.id
}

output "bucket_a_name" {
  description = "Private S3 bucket A name."
  value       = aws_s3_bucket.bucket_a.id
}

output "bucket_b_name" {
  description = "Private S3 bucket B name."
  value       = aws_s3_bucket.bucket_b.id
}

output "backend_instance_names" {
  description = "Backend EC2 instance names created by the foundation."
  value       = [for instance in aws_instance.backend : instance.tags.Name]
}

output "nat_instance_id" {
  description = "NAT instance ID."
  value       = aws_instance.nat.id
}

output "backend_role_names" {
  description = "One IAM role per backend EC2."
  value       = { for key, role in aws_iam_role.backend : key => role.name }
}

output "backend_instance_profile_names" {
  description = "One IAM instance profile per backend EC2."
  value       = { for key, profile in aws_iam_instance_profile.backend : key => profile.name }
}
