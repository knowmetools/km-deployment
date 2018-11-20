################################################################################
#                                  Variables                                   #
################################################################################

variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate to use for the distribution."
  type        = "string"
}

variable "application" {
  description = "The name of the application."
  type        = "string"
}

variable "base_tags" {
  description = "A base set of tags to apply to resources."
  default     = {}
  type        = "map"
}

variable "domain" {
  description = "The domain name to use for the distribution."
  type        = "string"
}

variable "domain_zone_id" {
  description = "The ID of the Route 53 hosted zone to create an A record in."
  type        = "string"
}

locals {
  app_slug     = "${lower(replace(var.application, " ", "-"))}"
  s3_origin_id = "S3Origin"
}

################################################################################
#                                  Resources                                   #
################################################################################

resource "aws_s3_bucket" "source" {
  bucket_prefix = "${local.app_slug}-"
  force_destroy = true

  tags = "${merge(
    var.base_tags,
    map(
      "Name", "${var.application}"
    )
  )}"
}

resource "aws_cloudfront_distribution" "s3" {
  aliases             = ["${var.domain}"]
  default_root_object = "index.html"
  enabled             = true
  price_class         = "PriceClass_100"

  tags = "${merge(
    var.base_tags,
    map(
      "Name", "${var.application} Static Files"
    )
  )}"

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
    target_origin_id       = "${local.s3_origin_id}"
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
    target_origin_id       = "${local.s3_origin_id}"
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
    domain_name = "${aws_s3_bucket.source.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${var.acm_certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_route53_record" "root_domain" {
  name    = "${var.domain}"
  type    = "A"
  zone_id = "${var.domain_zone_id}"

  alias {
    name                   = "${aws_cloudfront_distribution.s3.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.s3.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_policy" "cloudfront" {
  bucket = "${aws_s3_bucket.source.id}"

  policy = <<EOF
{
  "Version":"2012-10-17",
  "Id":"PolicyForCloudFrontPrivateContent",
  "Statement":[
    {
      "Sid":" Grant a CloudFront Origin Identity access to support private content",
      "Effect":"Allow",
      "Principal": {
        "CanonicalUser": "${aws_cloudfront_origin_access_identity.origin_access_identity.s3_canonical_user_id}"
      },
      "Action":"s3:GetObject",
      "Resource":"arn:aws:s3:::${aws_s3_bucket.source.id}/*"
    }
  ]
}
EOF
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {}

################################################################################
#                                   Outputs                                    #
################################################################################

output "s3_bucket" {
  value = "${aws_s3_bucket.source.bucket}"
}

output "cloudfront_url" {
  value = "${aws_route53_record.root_domain.fqdn}"
}
