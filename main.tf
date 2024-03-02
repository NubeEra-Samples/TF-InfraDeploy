# 01. Create AWS Provider
provider "aws" {
    region   = "us-east-2"
    profile  = "nubeera"  
}

# 02. Create S3 Bucket, Object Lock, CORS Rules
resource "aws_s3_bucket" "bucketfrancis" {
  bucket = "bucketfrancis"
  acl = "public-read"
  force_destroy = true
  object_lock_configuration {
    object_lock_enabled = "Enabled"
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT","POST"]
    allowed_origins = ["https://mujahedh.com"]
    expose_headers = ["ETag"]
    max_age_seconds = 4000
  }
}

# 03. Execute/Clone Locally Project
resource "null_resource" "cloning-data" {
    depends_on = ["aws_s3_bucket.bucketfrancis"]
    provisioner "local-exec" {
        command = "git clone https://github.com/NubeEra-Samples/static-resources.git mybadges"    
    }  
}

# 04. Upload obj --> CloudFront
resource "aws_s3_bucket_object" "obj" {
    depends_on = [ aws_s3_bucket.bucketfrancis, null_resource.cloning-data ]
    bucket = "bucketfrancis"
    key = "mastry_badge.jpg"
    source = "mybadges/mastry_badge.jpg"
    acl = "public-read"
}

# 05. Create EC2 Instance( Execute SSH based Installing Apache2)
resource "aws_instance" "web01" {
  ami = "ami-05fb0b8c1424f266b"
  instance_type = "t2.micro"
  key_name = "mujahed"
  vpc_security_group_ids = ["sg-442f3733","sg-00c1ce33d5587a75e"]
  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file("c:/Users/info/.ssh/mujahed.pem")
    host = aws_instance.web01.public_ip
  }  
  tags = {
        Name = "web01"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt install apache2 php git -y",
      "sudo systemctl restart apache2",
      "sudo systemctl enable apache2"
    ]    
  }
}

# 06.1 Create EBS Volume
resource "aws_ebs_volume" "myVolume" {
  availability_zone = aws_instance.web01.availability_zone
  size = 1
  encrypted = true
  tags = {
    Name = "MyEBSVolume"
  }
}

# 06.2 Display Volume Id
output "myout_vol_id" {
  value = aws_ebs_volume.myVolume.id  
}

# 06.3 Attach Volume to EC2 Instance
resource "aws_volume_attachment" "ebs_attached" {
  device_name = "/dev/sde"
  volume_id = aws_ebs_volume.myVolume.id
  instance_id = aws_instance.web01.id
  force_detach =  true
}

# 06.3  Convert EBS Volume into File System ext4
resource "null_resource" "nullremote3" {
  depends_on = [ aws_volume_attachment.ebs_attached ]
  #SSH Connect
  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file("c:/Users/info/.ssh/mujahed.pem")
    host = aws_instance.web01.public_ip
  }
  #Execute Commands
  provisioner "remote-exec" {
    inline = [ 
      "sudo mkfs.ext4 /dev/xvde",
      "sudo mount /dev/xvde /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone git https://github.com/NubeEra-Samples/TF-InfraDeploy.git /var/www/html/",
     ]
    
  }
}

# 07.1 Create Snapshot
resource "aws_ebs_snapshot" "sample_snapshot" {
  volume_id = aws_ebs_volume.myVolume.id
  tags = {
    Name = "myEBS_Volsnap01"
  }  
}
# 07.2 Display Snapshot id
output "myout_snap_id" {
  value = aws_ebs_snapshot.sample_snapshot.id
}

# 08. Start Chrome --> PublicIP
resource "null_resource" "nulllocal1" {
  depends_on = [ null_resource.nullremote3 ]
  provisioner "local-exec" {
    command = "start chrome ${aws_instance.web01.public_ip}"
  }
}