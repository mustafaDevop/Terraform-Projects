resource "aws_appautoscaling_target" "prod_backend_web" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.prod.name}/${aws_ecs_service.prod_backend_web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "prod_backend_web_cpu" {
  name               = "prod-backend-web-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.prod_backend_web.resource_id
  scalable_dimension = aws_appautoscaling_target.prod_backend_web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.prod_backend_web.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80
  }

  depends_on = [aws_appautoscaling_target.prod_backend_web]
}
