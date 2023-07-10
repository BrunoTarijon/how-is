data "cloudflare_zone" "brunotarijon" {
  name = "brunotarijon.com"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "howis.brunotarijon.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "cert" {
  zone_id = data.cloudflare_zone.brunotarijon.id
  name    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  value   = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value
  type    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
}

resource "aws_apigatewayv2_domain_name" "howis" {
  domain_name = "howis.brunotarijon.com"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "cloudflare_record" "how_is" {
  zone_id = data.cloudflare_zone.brunotarijon.id
  name    = aws_apigatewayv2_domain_name.howis.id
  value   = aws_apigatewayv2_domain_name.howis.domain_name_configuration[0].target_domain_name
  type    = "CNAME"
}
