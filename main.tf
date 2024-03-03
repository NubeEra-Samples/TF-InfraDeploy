#provider info
provider "aws" {
  region   = "us-east-2"
  profile  = "nubeera"
}

#creating s3
resource "aws_s3_bucket" "bucketmujahedh" {
  bucket = "bucketmujahedh"
  force_destroy = true
  object_lock_enabled = true
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["https://mujahedh.com"]
    expose_headers  = ["ETag"]
    max_age_seconds  = 4000
  }
}

resource "aws_s3_bucket_acl" "bucket_mujahedh_acl_configuration" {
  depends_on = [
    aws_s3_bucket.bucketmujahedh,
  ]
  bucket = aws_s3_bucket.bucketmujahedh.id
  acl    = "private"
}

#to cloning data to local
resource "null_resource" "cloning-data" {
  depends_on = ["aws_s3_bucket.bucketmujahedh"]
  provisioner "local-exec" {
      command = "git clone https://github.com/NubeEra-Samples/static-resources.git mybadges"
  }
}

#upload
resource "aws_s3_bucket_object" "obj" {
  depends_on = [aws_s3_bucket.bucketmujahedh,null_resource.cloning-data]
  bucket = "bucketmujahedh"
  key = "mastry_badge.jpg"
  source = "mybadges/mastry_badge.jpg"
  acl = "private"
}

# creating cloudfront s3 distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name =  "${aws_s3_bucket.bucketmujahedh.bucket_regional_domain_name}"
    origin_id   =  "S3-${aws_s3_bucket.bucketmujahedh.bucket}"
    custom_origin_config {
       http_port = 80
       https_port = 443
       origin_protocol_policy = "match-viewer"
       origin_ssl_protocols = ["TLSv1","TLSv1.1","TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "mujahedhussaini"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.bucketmujahedh.bucket}"

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

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.bucketmujahedh.bucket}"


    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "cloud_production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

#creating ec2 instance as webserver
resource "aws_instance" "web01" {
  ami           = "ami-05fb0b8c1424f266b"
  instance_type = "t2.micro"
  key_name      = "mujahed"
  vpc_security_group_ids = ["sg-442f3733","sg-00c1ce33d5587a75e"]
  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file("c:/Users/info/.ssh/mujahed.pem")
    host    = aws_instance.web01.public_ip
  } 

  provisioner "remote-exec" {
    inline = [
      "sudo apt install apache2 php git -y",
      "sudo systemctl restart apache2",
      "sudo systemctl enable apache2",
    ]
  }
  tags = {
    Name = "MYFirstTerraOS"
  }
}

#creating volume
resource "aws_ebs_volume" "myVolume" {
	availability_zone = aws_instance.web01.availability_zone
	size = 1
	encrypted = "true" 
	tags = {
		Name = "MyEBSVolume"
	}
}

output "myout_vol_id" {
	value = aws_ebs_volume.myVolume.id
}


#attaching volume
resource "aws_volume_attachment" "ebs_attached" {
  device_name = "/dev/sde"
  volume_id   = aws_ebs_volume.myVolume.id
  instance_id = aws_instance.web01.id
  force_detach = true
}

#creating a text file that store the public ip 
resource "null_resource" "nullrsclo01"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web01.public_ip} > publicip.txt"
  }
}

#creating a null resource to provision the partitions
resource "null_resource" "nullremote3"  {
  depends_on = [
      aws_volume_attachment.ebs_attached,
  ]
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("c:/Users/info/.ssh/mujahed.pem")
    host     = aws_instance.web01.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvde",
      "sudo mount  /dev/xvde  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/NubeEra-Temps/webserberProvisioning.git /var/www/html/"
    ]
  }
}


#creating snapshot
resource "aws_ebs_snapshot" "Sample_Snapshot" {
  volume_id = aws_ebs_volume.myVolume.id
  tags = {
    Name = "myEBS_Volsnap01"
  }
}

output "myout_snap_id" {
	value = aws_ebs_snapshot.Sample_Snapshot.id
}

resource "null_resource" "nulllocal1"  {
  depends_on = [
    null_resource.nullremote3,
  ]
	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.web01.public_ip}"
  	}
}