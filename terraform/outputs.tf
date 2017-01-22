output "webs_pub" {
  value = "${join(",", aws_instance.web.*.public_ip)}"
}

output "webs_priv" {
  value = "${join(",", aws_instance.web.*.private_ip)}"
}

output "db_pub" {
  value = "${aws_instance.db.public_ip}"
}

output "db_priv" {
  value = "${aws_instance.db.private_ip}"
}

output "lb_priv" {
  value = "${aws_instance.lb.private_ip}"
}

output "lb_pub" {
  value = "${aws_instance.lb.public_ip}"
}

output "address" {
  value = "${aws_instance.lb.public_ip}"
}
