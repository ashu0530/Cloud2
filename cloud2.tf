#Declare provider to tell terraform which cloud we need to contact

provider "aws" {
  profile = "ashu"     
  region  =   "ap-south-1"    
}

#Creating Variable For Our Resources
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default = "10.0.0.0/16"
}
variable "subnet_cidr1" {
  description = "CIDR block for the subnet"
  default = "10.0.0.0/24"
}

variable "subnet_cidr2" {
  description = "CIDR block for the subnet"
  default = "10.0.1.0/24"
}

variable "availability_zone1" {
  description = "availability zone"
  default = "ap-south-1a"
}

variable "availability_zone2" {
  description = "availability zone"
  default = "ap-south-1b"
}

variable "instance_ami_id" {
  description = "AMI for AWS EC2 instance"
  default = "ami-0ebc1ac48dfd14136"
}
variable "instance_type" {
  description = "Type for AWS EC2 instance"
  default = "t2.micro"
}


#Create VPC
resource "aws_vpc" "project2_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default" 
  tags= {
     Name = "project2-vpc"
   }
}

#Create Subnet 1a
resource "aws_subnet" "project2_subnet1" {
  
  availability_zone = "${var.availability_zone1}"
  vpc_id            = "${aws_vpc.project2_vpc.id}"
  cidr_block        = "${var.subnet_cidr1}"
  map_public_ip_on_launch = "true"
  tags= {
     Name = "project2-subnet1a"
}
  depends_on = [
    aws_vpc.project2_vpc,
  ] 
}

resource "aws_subnet" "project2_subnet2" {
  
  availability_zone = "${var.availability_zone2}"
  vpc_id            = "${aws_vpc.project2_vpc.id}"
  cidr_block        = "${var.subnet_cidr2}"
  map_public_ip_on_launch = "true"
  tags= {
     Name = "project2-subnet1b"
}
  depends_on = [
    aws_vpc.project2_vpc,
  ] 
}


#Create Internet Gateway
resource "aws_internet_gateway" "project2_internet_gateway" {
  vpc_id = "${aws_vpc.project2_vpc.id}"
  tags = {
    Name = "project2-ig"
  }
  depends_on = [
    aws_vpc.project2_vpc,
  ]
}

#Create Route Table
resource "aws_route_table" "project2_route_table" {
  vpc_id = "${aws_vpc.project2_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.project2_internet_gateway.id}"
  }
  tags = {
    Name = "project2-route-table"
  }
  depends_on = [
    aws_vpc.project2_vpc,
  ]
}

#Create Route Table Association 1a subnet
resource "aws_route_table_association" "project2_rta1" {
  subnet_id      = "${aws_subnet.project2_subnet1.id}"
  route_table_id = "${aws_route_table.project2_route_table.id}"
  depends_on = [
    aws_subnet.project2_subnet1,

  ]
}


#Create Route Table Association 1b subnet
resource "aws_route_table_association" "project2_rta2" {
  subnet_id      = "${aws_subnet.project2_subnet2.id}"
  route_table_id = "${aws_route_table.project2_route_table.id}"
  depends_on = [
    aws_subnet.project2_subnet1,

  ]
}

#Create Security Group
resource "aws_security_group" "project2_first_sg" {
  name        = "sg_for_project2"
  description = "allow ssh and http, https traffic"
  vpc_id      =  "${aws_vpc.project2_vpc.id}"

  ingress {
    description = "inbound_ssh_configuration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "all_traffic_outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  description = "http_configuration"  
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  
}
  ingress {
  description = "https_configuration"  
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  }  

  ingress {
    description = "NFS_configuration"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project2_sg1"
  }
}

output "firewall_sg1_info" {
  value = aws_security_group.project2_first_sg.name
}


# Create a key-pair for aws instance for login

#Generate a key using RSA algo
resource "tls_private_key" "instance_key2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#create a key-pair 
resource "aws_key_pair" "key_pair2" {
  key_name   = "project2_key1"
  public_key = "${tls_private_key.instance_key2.public_key_openssh}"
  depends_on = [  tls_private_key.instance_key2 ]
}

#save the key file locally inside workspace in .pem extension file
resource "local_file" "save_project2_key1" {
  content = "${tls_private_key.instance_key2.private_key_pem}"
  filename = "project2_key1.pem"
  depends_on = [
   tls_private_key.instance_key2, aws_key_pair.key_pair2 ]
}



#Instance_creation 1
resource "aws_instance" "project2_instance1" {
  ami           = "${var.instance_ami_id}"
  instance_type = "${var.instance_type}"
  key_name = aws_key_pair.key_pair2.key_name
  vpc_security_group_ids = [ "${aws_security_group.project2_first_sg.id}" ]
  subnet_id      = "${aws_subnet.project2_subnet1.id}"


  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = "${tls_private_key.instance_key2.private_key_pem}"
    host     = "${aws_instance.project2_instance1.public_ip}"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum -y install httpd php git",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo yum install -y amazon-efs-utils",
      "sudo yum install -y nfs-utils"
    ]
  }
  tags = {
    Name = "project2_webserver1"
  }
}
output "instance1_az" {
  value = aws_instance.project2_instance1.availability_zone
}
output "instance1_id" {
  value = aws_instance.project2_instance1.id
}
output "public_ip_webserver1" {
    value = aws_instance.project2_instance1.public_ip
}


#Instance_creation 2
resource "aws_instance" "project2_instance2" {
  ami           = "${var.instance_ami_id}"
  instance_type = "${var.instance_type}"
  key_name = aws_key_pair.key_pair2.key_name
  vpc_security_group_ids = [ "${aws_security_group.project2_first_sg.id}" ]
  subnet_id      = "${aws_subnet.project2_subnet2.id}"


  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = "${tls_private_key.instance_key2.private_key_pem}"
    host     = "${aws_instance.project2_instance2.public_ip}"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum -y install httpd php git",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo yum install -y amazon-efs-utils",
      "sudo yum install -y nfs-utils"
    ]
  }
  tags = {
    Name = "project2_webserver2"
  }
}
output "instance2_az" {
  value = aws_instance.project2_instance2.availability_zone
}
output "instance2_id" {
  value = aws_instance.project2_instance2.id
}
output "public_ip_webserver2" {
    value = aws_instance.project2_instance2.public_ip
}


#Create EFS 
resource "aws_efs_file_system" "project2_efs" {
  creation_token = "my_efs"
  encrypted = true
  tags = {
    Name = "project2-EFS"
  }
  depends_on = [ aws_instance.project2_instance1, 
                 aws_instance.project2_instance2,
  ]
}

#Mount EFS on 1a subnet
resource "aws_efs_mount_target" "project2_efs_mount1a" {
  file_system_id = "${aws_efs_file_system.project2_efs.id}"
  subnet_id      = "${aws_subnet.project2_subnet1.id}"
  security_groups = [ "${aws_security_group.project2_first_sg.id}" ]
  depends_on = [ aws_efs_file_system.project2_efs, 
  ]
}


#Mount EFS on 1b subnet
resource "aws_efs_mount_target" "project2_efs_mount1b" {
  file_system_id = "${aws_efs_file_system.project2_efs.id}"
  subnet_id      = "${aws_subnet.project2_subnet2.id}"
  security_groups = [ "${aws_security_group.project2_first_sg.id}" ]
  depends_on = [ aws_efs_file_system.project2_efs, 
  ]
}


#Mount EFS Permanent To First instance which is running on Subnet 1a

resource "null_resource" "permanent_mount_efs1" {
  connection {
  	  type     = "ssh"
   	  user     = "ec2-user"
   	  private_key = "${tls_private_key.instance_key2.private_key_pem}" 
   	  host = "${aws_instance.project2_instance1.public_ip}"
  }
  provisioner "remote-exec" {
      inline = [

      #Permission to owner, group, others of read, write on file
       "sudo chmod ugo+rw /etc/fstab",  

      #When the system/instance reboot then this command automatically remount the EFS volume to the instance
       "sudo echo '${aws_efs_mount_target.project2_efs_mount1a.ip_address}:/ /var/www/html nfs4 tls,_netdev 0 0' >> /etc/fstab",  

      #This command will mount our EFS volume to the document root directory of webserver 
       "sudo mount -t nfs4  ${aws_efs_mount_target.project2_efs_mount1a.ip_address}:/ /var/www/html", 
      
      #Download Content of Website from Github Repository and save to 'index.php' file on current directory 
       "sudo curl https://raw.githubusercontent.com/ashu0530/webpage/master/index.php > index.php", 

      #Copy 'index.php' to Document root directory of Web-Server
       "sudo cp index.php  /var/www/html", 
      
      ]
  }
  depends_on = [ aws_instance.project2_instance1,
               aws_efs_file_system.project2_efs,
               aws_efs_mount_target.project2_efs_mount1a,
               ]

}

#Mount EFS Permanent To Second instance which is running on Subnet 1b

resource "null_resource" "permanent_mount_efs2" {
  connection {
  	  type     = "ssh"
   	  user     = "ec2-user"
   	  private_key = "${tls_private_key.instance_key2.private_key_pem}" 
   	  host = "${aws_instance.project2_instance2.public_ip}"
  }
  provisioner "remote-exec" {
      inline = [

      #Permission to owner, group, others of read, write on file 
       "sudo chmod ugo+rw /etc/fstab", 

      #When the system/instance reboot then this command automatically remount the EFS volume to the instance
       "sudo echo '${aws_efs_mount_target.project2_efs_mount1b.ip_address}:/ /var/www/html nfs4 tls,_netdev 0 0' >> /etc/fstab",  

      #This command will mount our EFS volume to the document root directory of webserver 
       "sudo mount -t nfs4  ${aws_efs_mount_target.project2_efs_mount1b.ip_address}:/ /var/www/html", 

      #Download Content of Website from Github Repository and save to 'index.php' file on current directory 
       "sudo curl https://raw.githubusercontent.com/ashu0530/webpage/master/index.php > index.php", 

      #Copy 'index.php' to Document root directory of Web-Server
       "sudo cp index.php  /var/www/html", 
    ]
  }
  depends_on = [ aws_instance.project2_instance2,
               aws_efs_file_system.project2_efs,
               aws_efs_mount_target.project2_efs_mount1b,
               ]

}

#Create a S3-bucket
resource "aws_s3_bucket" "project2_bucket" {
    bucket = "project2webserverbucket"
    acl    = "public-read"
    force_destroy = true 
    tags   = {
        Name = "project2-bucket"
        Environment = "Production"
   }
    depends_on = [ null_resource.permanent_mount_efs1,
                   null_resource.permanent_mount_efs2,
     ]
}
output "project2_bucket_id" {
    value = aws_s3_bucket.project2_bucket.id
}

#Applying bucket public access policy
resource "aws_s3_bucket_public_access_block" "project2_bucket_public_access_policy" {
    bucket = "${aws_s3_bucket.project2_bucket.id}"      
    block_public_acls = false
    block_public_policy = false 
    restrict_public_buckets = false
  } 

#Upload image to S3-Bucket
resource "aws_s3_bucket_object" "project2_object" {
    bucket = aws_s3_bucket.project2_bucket.bucket
    key    = "project2_image.jpg"
    acl    = "public-read"
    source = "C:/Users/Ashutosh/Desktop/pic1.jpg"
      depends_on = [
    aws_s3_bucket.project2_bucket,
  ]      
}

output "project2_bucket_domain_name" {
  value = aws_s3_bucket.project2_bucket.bucket_regional_domain_name
}


#Creating cloudfront
locals {
  s3_origin_id = aws_s3_bucket.project2_bucket.bucket
}

resource "aws_cloudfront_distribution" "project2_cloudfront" {
  origin {
      domain_name = "${aws_s3_bucket.project2_bucket.bucket_regional_domain_name}"
      origin_id   = "${local.s3_origin_id}"
      custom_origin_config {
          http_port = 80
          https_port = 443
          origin_protocol_policy = "match-viewer"
          origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
    }
  }
  enabled         = true
  is_ipv6_enabled = true  
  comment             = "building_cf"
  default_root_object = "index.php"

  default_cache_behavior {
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "${local.s3_origin_id}"
      forwarded_values {
          query_string = false
          cookies {
              forward = "none"
          }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 120
      max_ttl                = 3600
}

  price_class = "PriceClass_All"

  restrictions {
      geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Name        = "project2_cloudfront"
    Environment = "production"
  }

  viewer_certificate {
      cloudfront_default_certificate = true
 
  }
  depends_on = [
      aws_s3_bucket_object.project2_object,
      null_resource.permanent_mount_efs1,
      null_resource.permanent_mount_efs2,
  ]

} 

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.project2_cloudfront.domain_name
}


#locally saving the domain_name inside text file 
resource "null_resource" "cf_ip"  {
 provisioner "local-exec" {
     command = "echo  ${aws_cloudfront_distribution.project2_cloudfront.domain_name} > domain_name.txt"

   }
  depends_on = [   aws_cloudfront_distribution.project2_cloudfront, ]

}


#Updating in my website code of instance1
resource "null_resource" "project2_add_image1"  {
    connection {
  	  type     = "ssh"
   	  user     = "ec2-user"
   	  private_key = "${tls_private_key.instance_key2.private_key_pem}" 
   	  host = "${aws_instance.project2_instance1.public_ip}"
    }

    
    provisioner "remote-exec" {  
        inline = [ 
           
              "sudo sed -i '1i<img src='https://${aws_cloudfront_distribution.project2_cloudfront.domain_name}/project2_image.jpg' alt='ME' width='380' height='240' align='right'>' /var/www/html/index.php",
              "sudo sed -i '2i<p align='right'> <a href='https://www.linkedin.com/in/ashutosh-pandey-43b94b18b'>Visit To My LinkedIn Profile >>>> :) </a></p>' /var/www/html/index.php",

        ]                      
          
  } 
    depends_on = [    
aws_cloudfront_distribution.project2_cloudfront, 
 ]
 }


#Updating in my website code of instance2
resource "null_resource" "project2_add_image2"  {
    connection {
  	  type     = "ssh"
   	  user     = "ec2-user"
   	  private_key = "${tls_private_key.instance_key2.private_key_pem}" 
   	  host = "${aws_instance.project2_instance2.public_ip}"
    }

    
    provisioner "remote-exec" {  
        inline = [ 
           
              "sudo sed -i '1i<img src='https://${aws_cloudfront_distribution.project2_cloudfront.domain_name}/project2_image.jpg' alt='ME' width='380' height='240' align='right'>' /var/www/html/index.php",
              "sudo sed -i '2i<p align='right'> <a href='https://www.linkedin.com/in/ashutosh-pandey-43b94b18b'>Visit To My LinkedIn Profile >>>> :) </a></p>' /var/www/html/index.php",

        ]                      
          
  } 
    depends_on = [    
aws_cloudfront_distribution.project2_cloudfront, 
 ]
 }

 
 
 #launching chrome browser for opening my website of instance1
 resource "null_resource" "ChromeOpen1"  { 
     provisioner "local-exec" { 
           command = "start chrome ${aws_instance.project2_instance1.public_ip}"  
     }
     depends_on = [ null_resource.project2_add_image1,
     ]         
}

#launching chrome browser for opening my website of instance1
 resource "null_resource" "ChromeOpen2"  { 
     provisioner "local-exec" { 
           command = "start chrome ${aws_instance.project2_instance2.public_ip}"  
     }
     depends_on = [ null_resource.project2_add_image2,
     ]         
}
