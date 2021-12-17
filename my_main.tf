terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}
 
provider "aws" {
region ="us-east-2"
}

resource "aws_vpc" "server_vpc"{
  cidr_block ="10.1.0.0/24"
  tags={
   Name= "vpc_demo"


}
}

resource "aws_subnet" "subnet_2"{
  cidr_block ="10.1.0.64/26"

  vpc_id = "${aws_vpc.server_vpc.id }"

  availability_zone ="us-east-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "my_subnet_2"
}
}











resource "aws_subnet" "subnet_1"{
  cidr_block ="10.1.0.0/26"

  vpc_id = "${aws_vpc.server_vpc.id }"
  
  availability_zone ="us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "my_subnet_1"
}
}

resource "aws_security_group" "allow_ssh" {
  name        = "ssh_sg"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.server_vpc.id}"


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }





  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_security_group" "allow_http" {
  name        = "http_sg"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.server_vpc.id}"


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }





  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
}
resource "aws_security_group" "elb" {
  name        = "sg_elb"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.server_vpc.id}"

  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_lb" "web" {
  name = "alb"
  internal  = false
  load_balancer_type="application"
  
    
  subnets    =["${aws_subnet.subnet_1.id}" ,"${aws_subnet.subnet_2.id}"]

  security_groups= ["${aws_security_group.elb.id}"]

 }


resource "aws_lb_listener" "listener_http" {
  load_balancer_arn = "${aws_lb.web.id}"
  
  port     = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_lb_target_group.group.arn}"
    type             = "forward"  
}
}    
resource "aws_lb_target_group" "group" {
  name     = "elb-tg"
  target_type =     "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.server_vpc.id}"
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3

    interval            = 30
  }


}

resource "aws_lb_target_group_attachment" "demo1" {
  target_group_arn = "${aws_lb_target_group.group.id}"
  count             =  2
  target_id         = "${element(split(",", join(",", aws_instance.app_server.*.id)),count.index)}"
  port             = 80
}
resource "aws_lb_target_group_attachment" "demo2" {
  target_group_arn = "${aws_lb_target_group.group.id}"
  count             =  2
  target_id         = "${element(split(",", join(",", aws_instance.app_server_1.*.id)),count.index)}"
  port             = 80
}




resource "aws_instance" "app_server" {
  count         =  2
  ami           = "ami-0fb653ca2d3203ac1"
  


  instance_type = "t2.micro"
  key_name = "${aws_key_pair.deployer.key_name}"
  subnet_id = "${aws_subnet.subnet_1.id}"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}" , "${aws_security_group.allow_http.id}"    ] 
  associate_public_ip_address = true
  tags = {
    Name = "server_instance-${count.index + 1}"
  }
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key= "${file("./id_rsa")}"
    host     = self.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install nginx -y",
      "sudo systemctl start nginx",
      "echo '<h1>Deployed via remote exec provisioner</h1>' | sudo tee /var/www/html/index.html"
    ]
  }





}


resource "aws_instance" "app_server_1" {
  count         =  2
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.deployer.key_name}"
  subnet_id = "${aws_subnet.subnet_2.id}"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}" , "${aws_security_group.allow_http.id}"]
  associate_public_ip_address = true
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install nginx -y",
      "sudo systemctl start nginx",
      "echo '<h1>Deployed via remote exec provisiner 1</h1>' | sudo tee /var/www/html/index.html"
    ]
  }




  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key= "${file("./id_rsa")}"
    host     = self.public_ip
  }

  tags = {
    Name = "other_instance-${count.index + 1}"
  }

}
resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key =  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCgGTsMxj08EksahMSweIaiVUU7qvVUWIitphLFrIMUvvYrcwESCzUmieDhr7K509WwijpUJHxmpnj6QYGAEj7JYI3o3qYuLK43Yk/TTd7TBhusnMJRxCKC2rONF2LJCHIepd1O41JTsrzon13LQIPZRJNUAxLtLOtAUpcivoz5GryiBIk8EtqJKWFwLEn1gQ45ddUDHwP4qW/ZmL/Ks61xBOAIwUHMtaOarEf1YFkWeRZNDpsmK6Kb/UgAxvTqDl4JoFa0IAdwSCoOuREvkp5FnW//lEzvL1skfPfyOO7P6pT6f238p7OymNbjgqi26G8polqpZD3lFSNN3Fk4gBntmoW1Mct0+0o0NyDtq5RmMSpoBROjtq+cYYi80vyaQOEzIIqWrnAelmN//ztaTRlSJHXWmD9JUVbV5P79ZbnXqQfdbHG7itkkavnssvNf6LyGZNg53PjlRpc6dxnxHiPc1/VTKzE9uLLTkWgMdkY4MZVZ4/RNdxvi18a+V9qBJXs= NUZRA@LAPTOP-445OOJT1"
}
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.server_vpc.id }"

  tags = {
    Name = "internet_gateway"
  }
}
resource "aws_route_table" "my_table" {
  vpc_id =  "${aws_vpc.server_vpc.id }"


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

}
resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = "${aws_subnet.subnet_1.id}"

  route_table_id = "${aws_route_table.my_table.id}"
}
resource "aws_route_table_association" "rta_subnet_other_public" {
  subnet_id      = "${aws_subnet.subnet_2.id}"

  route_table_id = "${aws_route_table.my_table.id}"
}
