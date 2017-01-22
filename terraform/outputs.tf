output "address" {
  value = "${aws_elb.web.dns_name}"
}

output "webs" {
  value = "${join(",", aws_instance.web.*.public_ip)}"
}

output "db_pub" {
  value = "${aws_instance.db.public_ip}"
}

output "db_priv" {
  value = "${aws_instance.db.private_ip}"
}
