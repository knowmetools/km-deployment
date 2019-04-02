output "api_elb_dns_name" {
  value = "${aws_lb.api.dns_name}"
}

output "api_elb_zone_id" {
  value = "${aws_lb.api.zone_id}"
}
