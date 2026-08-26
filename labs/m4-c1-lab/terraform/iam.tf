resource "aws_iam_role" "backend" {
  for_each = local.backend_instances

  name = "${local.name_prefix}-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-role"
    Role = each.value.group
  })
}

resource "aws_iam_instance_profile" "backend" {
  for_each = aws_iam_role.backend

  name = "${local.name_prefix}-${each.key}-profile"
  role = each.value.name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-profile"
  })
}

resource "aws_iam_role_policy_attachment" "backend_ssm" {
  for_each = aws_iam_role.backend

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "backend_s3_full_initial" {
  for_each = aws_iam_role.backend

  name = "s3-lab02-full-buckets"
  role = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "InitialFullAccessToLabBuckets"
      Effect = "Allow"
      Action = "s3:*"
      Resource = [
        aws_s3_bucket.bucket_a.arn,
        "${aws_s3_bucket.bucket_a.arn}/*",
        aws_s3_bucket.bucket_b.arn,
        "${aws_s3_bucket.bucket_b.arn}/*"
      ]
    }]
  })
}
