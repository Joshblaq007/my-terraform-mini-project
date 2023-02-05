output "elb_load_balancer_group_arn" {
  value = aws_lb_target_group.terraform-target-group.arn
}

output "elb_load_balancer_dns_name" {
  value = aws_lb.terraform-load-balancer.dns_name
}

output "elb_load_balancer_zone_id" {
  value = aws_lb.terraform-load-balancer.zone_id
}


