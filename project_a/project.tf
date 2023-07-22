# START OF PROJECT A

# Launch Template
# Defines the setup of our EC2 instances when they are provisioned
resource "aws_launch_template" "template" {
  name = "template"
  instance_type = "t2.micro"

  # TLDR: I have chosen the AMI id of the latest Amazon Linux 2 to use for the workshop
  image_id = data.aws_ami.linux-us-east.id
  vpc_security_group_ids = [ "${aws_security_group.workshop_sg.id}" ]
  
  # This is the userdata/boot-up script of the instance
  # When the instance is first created, it would run the commands in the shell script file only once
  user_data = filebase64("./user-data.sh")
}

# Creating our Application Load Balancer
# We will be provision one ALB per subnet/availability-zone
resource "aws_lb" "load_balancer" {
  name = "load-balancer"
  internal = false
  load_balancer_type = "application"

  # Attaching workshop security group
  security_groups = [aws_security_group.workshop_sg.id]

  # Declaring which subnets the ALBs will be provisioned in
  subnets = [aws_subnet.east-1a-subnet.id, aws_subnet.east-1b-subnet.id]
}

# Creating the Target Group for ALB
# Essentially all resources in a target group will receive traffic from the ALB
# NOTE: The target group we are making is EMPTY ON PURPOSE, as we are going to insert an Auto Scaling Group inside
resource "aws_lb_target_group" "target_group" {
  name = "target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.workshop-vpc.id
  

  health_check {
    port = 80
    protocol = "HTTP"
  }

  # Something extra
  # Ensures that a new target group is created before the destruction of the old one to ensure zero downtime
  lifecycle {
    create_before_destroy = true
  }
}

# Creating the Listener for ALB
# This is essentially what connects the ALB to the target group
# It forwards all HTTP traffic entering the ALB to the associated target group
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.id
  port = "80"
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target_group.id
    type = "forward"
  }
}

# Auto Scaling Group
# This is placed inside of the target group
# The ASG will support a minimum of 2 instances and a maximum of 4 instances. When first created, it will provision 2 instances to start off
# The ASG will span 2 availability zones, us-east-1a and us-east-1b
resource "aws_autoscaling_group" "auto_scaling_group" {
  # Linking subnets
  vpc_zone_identifier = [aws_subnet.east-1a-subnet.id, aws_subnet.east-1b-subnet.id]
  name = "auto-scaling-group"

  # Desired = starting number of instances (when ASG is first provisioned)
  # Minimum = minimum number of instances that must always be present
  # Maximum = maximum number instances that can be present at one time
  desired_capacity = 2
  max_size = 4
  min_size = 2

  # Linking target group
  target_group_arns = [aws_lb_target_group.target_group.arn]

  # Setting the launch template, every instances made by the ASG will follow the template
  launch_template {
    id = aws_launch_template.template.id
    version = "$Latest"
  }
}

# Scaling Out Policy (Increases Number of Instances)
# Adds 1 instance to the ASG when activated
# After policy is activated, it cannot trigger until 5 minutes pass
resource "aws_autoscaling_policy" "scale_out_policy" {
  name = "scale_out_policy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.auto_scaling_group.name
}

# CloudWatch Alarm to trigger Scaling out Policy
# If CPUUtilization >= 40% during a 2 minute period, activate the scaling out policy
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_name = "scale_out_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 120
  statistic = "Average"
  threshold = 40

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.auto_scaling_group.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out_policy.arn]
}

# Scaling In Policy (Decreases Number of Instances)
# Removes 1 instance from the ASG when activated
# After policy is activated, it cannot trigger until 5 minutes pass
resource "aws_autoscaling_policy" "scale_in_policy" {
  name = "scale_in_policy"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.auto_scaling_group.name
}

# CloudWatch Alarm to trigger Scaling In Policy
# If CPUUtilization <= 20% during a 2 minute period, activate the scaling in policy
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_name = "scale_in_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = 1
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 120
  statistic = "Average"
  threshold = 20

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.auto_scaling_group.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in_policy.arn]
}

# Outputting ALB DNS name for convenience -> You can see the output in the CLI after performing a "terraform apply"
# You can use this output to access your load balancer
output "alb_DNS" {
  value = aws_lb.load_balancer.dns_name
}

# CLI Commands for Instance Stress Testing - I WILL DO A LIVE DEMO, DO NOT UNCOMMENT
# sudo amazon-linux-extras install epel -y
# sudo yum install stress -y
# stress -c 4