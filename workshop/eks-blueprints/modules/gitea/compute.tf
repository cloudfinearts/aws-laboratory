resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.shared.name
}

data "aws_ssm_parameter" "image" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# use session manager for access
resource "aws_instance" "this" {
  availability_zone = data.aws_availability_zones.this.names[0]
  subnet_id         = aws_subnet.this.id

  ebs_block_device {
    device_name           = "/dev/xvda"
    delete_on_termination = true
    encrypted             = true
    volume_size           = 30
    volume_type           = "gp3"
  }

  iam_instance_profile        = aws_iam_instance_profile.this.name
  ami                         = data.aws_ssm_parameter.image.value
  instance_type               = "t3.medium"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ide.id]
}

resource "aws_cloudfront_distribution" "this" {
  enabled      = true
  http_version = "http2"
  # cheapest, server only from major edge locations
  price_class = "PriceClass_100"

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "PUT",
      "PATCH",
      "POST",
      "DELETE"
    ]
    # managed AWS policy - caching disabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # when a cache is miss, cloudfront sends origin request to get the content
    # origin request does include neither query params nor headers from viewer request by default
    # AllViewer policy to include everything
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    compress                 = true
    # cannot be empty
    cached_methods = ["GET", "HEAD"]
    # origin server or S3 bucket
    target_origin_id       = "ec2-ide-origin"
    viewer_protocol_policy = "allow-all"
  }

  origin {
    origin_id = "ec2-ide-origin"
    custom_origin_config {
      http_port = 80
      # required field
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    domain_name = aws_instance.this.public_dns
  }

  # required blocks
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cf_url" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "instance_id" {
  value = aws_instance.this.id
}
