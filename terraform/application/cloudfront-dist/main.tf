################################################################################
#                                  Variables                                   #
################################################################################

variable "acm_certificate" {
  description = "The ACM certificate to use for the distribution."
  type        = object({ arn = string })
}

variable "app_name" {
  description = "The name of the application."
  type        = string
}

variable "app_slug" {
  description = "A slug used to identify the application"
  type        = string
}

variable "base_tags" {
  description = "A base set of tags to apply to resources."
  default     = {}
  type        = map(string)
}

variable "domain" {
  description = "The domain name to use for the distribution."
  type        = string
}

locals {
  s3_origin_id = "S3Origin"
}

################################################################################
#                                  Resources                                   #
################################################################################

resource "aws_s3_bucket" "source" {
  bucket        = var.app_slug
  force_destroy = true

  tags = merge(
    var.base_tags,
    {
      "Name" = var.app_name
    },
  )
}

resource "aws_cloudfront_distribution" "s3" {
  aliases             = [var.domain]
  default_root_object = "index.html"
  enabled             = true
  price_class         = "PriceClass_100"

  tags = merge(
    var.base_tags,
    {
      Name = var.app_name
    },
  )

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  default_cache_behavior {
    allowed_methods        = ["HEAD", "GET", "OPTIONS"]
    cached_methods         = ["HEAD", "GET", "OPTIONS"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers      = []
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  ordered_cache_behavior {
    allowed_methods        = ["HEAD", "GET", "OPTIONS"]
    cached_methods         = ["HEAD", "GET", "OPTIONS"]
    default_ttl            = 300
    max_ttl                = 600
    min_ttl                = 0
    path_pattern           = "/index.html"
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers      = []
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.source.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.acm_certificate.arn
    ssl_support_method  = "sni-only"
  }
}

resource "aws_s3_bucket_policy" "cloudfront" {
  bucket = aws_s3_bucket.source.id
  policy = data.aws_iam_policy_document.cloudfront_s3_access.json
}

data "aws_iam_policy_document" "cloudfront_s3_access" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.source.arn}/*"]

    principals {
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
      type        = "AWS"
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {}

################################################################################
#                                   Outputs                                    #
################################################################################

output "s3_bucket" {
  value = aws_s3_bucket.source
}

output "cloudfront_dist" {
  value = aws_cloudfront_distribution.s3
}

