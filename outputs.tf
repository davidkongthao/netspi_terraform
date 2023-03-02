output "s3_bucket_id" {
    value = aws_s3_bucket.main.id
}

output "efs_id" {
    value = aws_efs_file_system.main.id
}

output "instance_id" {
    value = aws_instance.main.id
}

output "security_group_ids" {
    value = [
        aws_security_group.main.id,
        aws_security_group.efs.id
    ]
}

output "subnet_id" {
    value = aws_subnet.main.id
}

output "public_ip" {
    value = aws_instance.main.public_ip
}