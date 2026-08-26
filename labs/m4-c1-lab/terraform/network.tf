resource "aws_vpc" "this" {
  cidr_block           = "10.41.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = {
    public-az1 = {
      cidr = "10.41.0.0/24"
      az   = local.availability_zones[0]
    }
    public-az2 = {
      cidr = "10.41.1.0/24"
      az   = local.availability_zones[1]
    }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "private_app" {
  for_each = {
    backend-a-az1 = {
      cidr = "10.41.10.0/24"
      az   = local.availability_zones[0]
      app  = "backend-a"
    }
    backend-a-az2 = {
      cidr = "10.41.11.0/24"
      az   = local.availability_zones[1]
      app  = "backend-a"
    }
    backend-b-az1 = {
      cidr = "10.41.20.0/24"
      az   = local.availability_zones[0]
      app  = "backend-b"
    }
    backend-b-az2 = {
      cidr = "10.41.21.0/24"
      az   = local.availability_zones[1]
      app  = "backend-b"
    }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Tier = each.value.app
  }
}

resource "aws_subnet" "private_db" {
  for_each = {
    db-az1 = {
      cidr = "10.41.30.0/24"
      az   = local.availability_zones[0]
    }
    db-az2 = {
      cidr = "10.41.31.0/24"
      az   = local.availability_zones[1]
    }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-${each.key}"
    Tier = "db"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  for_each = aws_subnet.private_app

  vpc_id = aws_vpc.this.id


  tags = {
    Name = "${local.name_prefix}-${each.key}-rt"
  }
}

resource "aws_route" "app_default_to_nat" {
  for_each = aws_route_table.app

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "db" {
  for_each = aws_subnet.private_db

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-${each.key}-rt"
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db[each.key].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.app : route_table.id]

  tags = {
    Name = "${local.name_prefix}-s3-gateway"
  }
}
