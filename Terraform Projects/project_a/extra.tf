# Data Block for US East
# TLDR: Gets the latest Amazon Linux 2 Image in us-east-1
data "aws_ami" "linux-us-east" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}