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
