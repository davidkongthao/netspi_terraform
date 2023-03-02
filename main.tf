data "aws_availability_zones" "main" {
    state = "available"
}

data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["099720109477"]
}

locals {
    default_az = data.aws_availability_zones.main.names[0]
    cidr_block = "172.24.10.0/24"
    name = "NetSPI"
    key_name = lower("${local.name}_key")
    key_file_path = "./assets/${local.key_name}"
    mnt_point = "/data/test"
    shell_file = "./assets/user_data.sh"
    efs_utils_path = "/tmp/efs-utils"
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
    content = tls_private_key.main.private_key_openssh
    filename = "${local.key_file_path}"
    provisioner "local-exec" {
        command = "chmod 400 ${local.key_file_path}"
    }
}

resource "local_file" "public_key" {
    content = tls_private_key.main.public_key_openssh
    filename = "${local.key_file_path}.pub"
}

resource "aws_s3_bucket" "main" {
    bucket = lower("${local.name}-challenge-bucket")
    force_destroy = true
}

# resource "aws_s3_access_point" "main" {
#     bucket = aws_s3_bucket.main.id
#     name = lower("${local.name}-access-point")
#     vpc_configuration {
#       vpc_id = aws_vpc.main.id
#     }
# }

resource "aws_s3_bucket_public_access_block" "main" {
    bucket = aws_s3_bucket.main.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_kms_key" "main" {
    description = "${local.name} KMS Key"
    customer_master_key_spec = "SYMMETRIC_DEFAULT"
    key_usage = "ENCRYPT_DECRYPT"
    enable_key_rotation = true
}

resource "aws_kms_alias" "kms_key_alias" {
    name = lower("alias/${local.name}-kms-key")
    target_key_id = aws_kms_key.main.key_id
}

resource "aws_vpc" "main" {
    cidr_block = "${local.cidr_block}"
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "${local.name}-VPC"
    }
}

resource "aws_subnet" "main" {
    vpc_id = aws_vpc.main.id
    cidr_block = "${local.cidr_block}"
    availability_zone = local.default_az

    tags = {
        Name = "${local.name}-Subnet"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "${local.name}-Gateway"
    }
}

resource "aws_default_route_table" "main" {
    default_route_table_id = aws_vpc.main.default_route_table_id
    route {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.main.id
    }
    
    tags = {
        Name = "${local.name}-Default-Route-Table"
    }
}

resource "aws_security_group" "main" {
    name = lower("${local.name}-main-sg")
    description = "Main Security Group"
    vpc_id = aws_vpc.main.id

    ingress {
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = var.allowed_cidr_blocks
    }

    ingress {
        protocol = "tcp"
        from_port = 2049
        to_port = 2049
        cidr_blocks = ["${local.cidr_block}"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }

    tags = {
        Name = lower("${local.name}-main-sg")
    }
}

resource "aws_security_group" "efs" {
    name = lower("${local.name}-efs-sg")
    description = "EFS Security Group"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port       = 2049
        to_port         = 2049
        protocol        = "tcp"
        security_groups = [aws_security_group.main.id]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    tags = {
        Name = lower("${local.name}-efs-sg")
    }
}

resource "aws_efs_file_system" "main" {
    creation_token = lower("${local.name}")
    availability_zone_name = local.default_az
    encrypted = true
    kms_key_id = aws_kms_key.main.arn
}

resource "aws_efs_mount_target" "main" {
    file_system_id = aws_efs_file_system.main.id
    subnet_id = aws_subnet.main.id
    security_groups = [aws_security_group.efs.id]
}

data "aws_eip" "main" {
    id = var.elastic_ip_id
}

resource "aws_key_pair" "main" {
    key_name = lower("${local.name}-key-pair")
    public_key = local_file.public_key.content
    tags = {
        Name = lower("${local.name}-key-pair")
    }
    depends_on = [
        local_file.private_key
    ]
}

resource "aws_eip_association" "main" {
    instance_id = aws_instance.main.id
    allocation_id = var.elastic_ip_id
}

resource "aws_iam_policy" "main" {
    name = lower("${local.name}-ec2-policy")
    path = "/"
    description = "Provides S3 permissions to EC2"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:GetObject",
                    "s3:PutObject",
                ]
                Resource = "${aws_s3_bucket.main.arn}/*"
            },
            {
                Effect = "Allow"
                Action = "s3:ListBucket"
                Resource = "${aws_s3_bucket.main.arn}"
            }
        ]
    })
}

resource "aws_iam_role" "main" {
    name = lower("${local.name}-ec2-role")
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid = "${local.name}EC2Role"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_policy_attachment" "main" {
    name = lower("${local.name}-ec2-attachment")
    roles = [aws_iam_role.main.name]
    policy_arn = aws_iam_policy.main.arn
}

resource "aws_iam_instance_profile" "main" {
    name = lower("${local.name}-profile")
    role = aws_iam_role.main.name
}

resource "aws_instance" "main" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
    iam_instance_profile = aws_iam_instance_profile.main.name
    availability_zone = local.default_az
    key_name = aws_key_pair.main.key_name

    root_block_device {
        volume_size     = 50
        volume_type     = "gp2"
        encrypted       = true
        kms_key_id      = aws_kms_key.main.key_id
    }

    subnet_id = aws_subnet.main.id
    security_groups = [aws_security_group.main.id]

    tags = {
        Name = lower("${local.name}-ec2")
    }

    lifecycle {
        ignore_changes = [
            root_block_device[0].kms_key_id,
            security_groups
        ]
    }
}

data "aws_efs_mount_target" "main" {
    mount_target_id = aws_efs_mount_target.main.id
}

resource "null_resource" "configure_efs" {
    depends_on = [aws_efs_mount_target.main, aws_instance.main, local_file.private_key]
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = local_file.private_key.content
        host = data.aws_eip.main.public_ip
    }
    provisioner "remote-exec" {
        inline = [
            "sudo apt-get -y update",
            "sudo apt-get -y install git binutils python3-pip",
            "sudo apt-get -y install awscli",
            "sudo pip3 install botocore",
            "git clone https://github.com/aws/efs-utils ${local.efs_utils_path}",
            "chmod 755 ${local.efs_utils_path}",
            "cd ${local.efs_utils_path}",
            "./build-deb.sh",
            "sudo apt-get -y install ./build/amazon-efs-utils*deb",
            "sudo mkdir /data",
            "cd /data",
            "sudo mkdir test",
            "cd /",
            "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${data.aws_efs_mount_target.main.ip_address}:/ ${local.mnt_point}",
            "sudo chmod 777 /etc/fstab",
            "sudo echo '${data.aws_efs_mount_target.main.ip_address}:/ ${local.mnt_point} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0' >> /etc/fstab",
            "sudo chmod 644 /etc/fstab",
            "sudo chmod 777 ${local.mnt_point}"
        ]
    }
}