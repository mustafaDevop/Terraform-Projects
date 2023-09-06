# Create Load Balancer
resource "aws_lb" "example_lb" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.eks_cluster_sg.id]
  subnets            = [aws_subnet.prod_public_1.id, aws_subnet.prod_public_2.id]
}

# Create Load Balancer Listener
resource "aws_lb_listener" "example_listener" {
  load_balancer_arn = aws_lb.example_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.example_target_group.arn
    type             = "forward"
  }
}

# Create Load Balancer Target Group
resource "aws_lb_target_group" "example_target_group" {
  name     = "example-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.prod.id
}

# Register EKS Cluster Instances with Target Group
resource "aws_lb_target_group_attachment" "example_target_group_attachment" {
  target_group_arn = aws_lb_target_group.example_target_group.arn
  target_id        = aws_eks_node_group.eks_node_group.id
  port             = 8080
}
