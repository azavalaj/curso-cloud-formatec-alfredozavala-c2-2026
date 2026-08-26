locals {
  name_prefix        = "m4-c1-${local.student_slug}"
  student_slug       = substr(replace(lower(var.student_identity), "/[^a-z0-9-]/", "-"), 0, 24)
  bucket_suffix      = substr(replace(lower("${data.aws_caller_identity.current.account_id}-${var.student_identity}"), "/[^a-z0-9-]/", "-"), 0, 48)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    StudentIdentity = var.student_identity
    Lab             = "m4-c1"
    ManagedBy       = "terraform"
  }

  backend_instances = {
    backend-a-01 = {
      subnet_key = "backend-a-az1"
      group      = "backend-a"
    }
    backend-a-02 = {
      subnet_key = "backend-a-az2"
      group      = "backend-a"
    }
    backend-b-01 = {
      subnet_key = "backend-b-az1"
      group      = "backend-b"
    }
    backend-b-02 = {
      subnet_key = "backend-b-az2"
      group      = "backend-b"
    }
  }
}
