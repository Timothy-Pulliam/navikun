resource "aws_acm_certificate" "cert" {
  domain_name       = "*.navikun.com"
  validation_method = "DNS"
  tags = {
    Environment = "dev"
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "this" {
  name         = "${var.app_name}.com"
  private_zone = false
}

resource "aws_route53_record" "this" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

# This resource implements a part of the validation workflow. 
# It does not represent a real-world entity in AWS, 
# therefore changing or deleting this resource 
# on its own has no immediate effect.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
}
