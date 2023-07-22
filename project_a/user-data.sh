#!/bin/bash
yum update -y # Updates all presently installed packages
yum install -y httpd # Installs the apache web server
systemctl start httpd # Starting the web server right now manually
systemctl enable httpd # Allows the web server to start automatically during system boot or startup
echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html # Create an index.html file and overwrite it to display the hostname ec2 instance that the user is currently on

# In short, this shell script file will be used to instruct our instances to download the needed libraries and start the web server
# Everytime a new instance is provisioned from our auto-scaling group, they will be setup according to these instructions