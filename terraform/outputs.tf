output "address" {
  value = "${aws_elb.web.dns_name}"
}

output "ip" {
  value = "${aws_instance.web.public_ip}"
}

#output "db" {
#  value = "${aws_db_instance.default.address}"
#}
