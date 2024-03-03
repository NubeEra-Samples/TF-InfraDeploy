provider "aws" {
  region   = "us-east-2"
  profile = "nubeera"
  # access_key       = "dretwutgdahoilskdhgfuj"
  # secret_key       = "trdf8w7GRYLFJDYUFGTEISUHDOILAHWTFUQGHFGUHgygfujfgugjdj"  
}

resource "aws_security_group" "mysecurity" {
  name        = "mysecurity"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-c7e4f9af"

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
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

  tags = {
    Name = "MySecurityGroup"
  }
}

#creating instance
resource "aws_instance" "web01" {
  depends_on=[aws_security_group.mysecurity]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = "mujahed"
  security_groups = ["mysecurity"] 
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/info/.ssh/mujahed.pem")
    host    = aws_instance.web01.public_ip
  }
     
     provisioner "remote-exec" {
    inline = [
      "sudo yum install git -y",
      "sudo yum install httpd -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "MYFirstTerraOS"
  }
}

output "myout_az" {
	value = aws_instance.web01.availability_zone
}

output "myout_public_ip" {
	value = aws_instance.web01.public_ip
}

output "myout_instance_id" {
	value = aws_instance.web01.id
}

resource "aws_efs_file_system" "efs" {
  creation_token = "my-product"
  tags = {
    Name = "efs_file_system"
  }
}
resource "aws_efs_mount_target" "alpha" {
depends_on=[ 
            aws_instance.web01, aws_efs_file_system.efs,aws_security_group.mysecurity]

  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_instance.web01.subnet_id
  security_groups=["${aws_security_group.mysecurity.id}"]
}

//formatting,mounting,import (Clone),restart the httpd service
resource "null_resource"  "myresource"{
depends_on=[ 
aws_efs_mount_target.alpha
]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key= file("C:/Users/info/.ssh/mujahed.pem")
    host     = aws_instance.web01.public_ip
  }
 provisioner "remote-exec" {
    inline = [
     "sudo mkfs.ext4 /dev/xvdh",
     "sudo  mount -t nfs4 ${aws_efs_mount_target.alpha.id} /var/www/html",
     "sudo rm -rf /var/www/html/*",
     "sudo git clone https://github.com/NubeEra-Temps/webserberProvisioning.git /var/www/html/", 
      "sudo su <<EOF",
      "echo \"${aws_cloudfront_distribution.prod_distribution.domain_name}\" >> /var/www/html/mydesti.txt",
      "EOF",
      "sudo systemctl restart httpd"
    ]
  }
}

resource "aws_s3_bucket" "b" {
  bucket = "bucketmujahedh"
  acl   = "public-read"
  force_destroy = true
  cors_rule {
     allowed_headers = ["*"]
     allowed_methods = ["PUT","POST"]
     allowed_origins = ["https://bucketmujahedh"]
     expose_headers = ["ETag"]
     max_age_seconds = 4000
  }
}

#to cloning data to local

resource "null_resource" "cloning-data" {
      depends_on = ["aws_s3_bucket.b"]
      provisioner "local-exec" {
         command = "git clone https://github.com/NubeEra-Temps/webserberProvisioning.git myimage"
      }
      
}

//creating cloudfront distribution
resource "aws_cloudfront_distribution" "prod_distribution" {
    origin {
         domain_name = "${aws_s3_bucket.b.bucket_regional_domain_name}"
         origin_id   = "${aws_s3_bucket.b.bucket}"
 
        custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
    # By default, show index.html file
    default_root_object = "index.php"
    enabled = true
    # If there is a 404, return index.html with a HTTP 200 Response
    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/index.php"
    }

default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.b.bucket}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE","IN"]
    }
  }

    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}


resource  "null_resource"  "myresource1"{
depends_on=[aws_cloudfront_distribution.prod_distribution]
provisioner "local-exec" {
    command = "start chrome ${aws_instance.web01.public_ip}"
  }
}