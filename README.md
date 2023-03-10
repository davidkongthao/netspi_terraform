# NetSPI Terraform Challenge
This is a terraform module built to complete the DevOps Engineer Terraform challenge for NetSPI. The main goal of this terraform repo is to provision:

1. S3 bucket with private access permissions
2. EFS volume
3. EC2 instance with SSH access
4. All required resources like VPC, Subnets, Security Groups etc. to provision above mentioned resources

## Conditions
1. An elastic IP provisioned in step 1 should be assigned to the provisioned EC2 instance for its public IP
2. EFS volume should be mounted on the EC2 instance at /data/test while it boots up
3. One should be able to write data to mounted EFS volume
4. One should be able to write data to the provisioned S3 bucket (No AWS credentials should be stored/set on the EC2 instance)
5. Terraform should display S3 Bucket ID, EFS volume ID, EC2 instance ID, Security Group ID, Subnet ID as part of output generated by Terraform apply command

## Cloning and Provisioning

1. `git clone https://github.com/davidkongthao/netspi_terraform.git` if using HTTPS or `git clone git@github.com:davidkongthao/netspi_terraform.git` if using SSH
2. Change the directory to that of the clone repo `cd netspi_terraform`
3. Create a new file called `terraform.tfvars` in the root of the repo. On Mac/Linux `touch terraform.tfvars` or Windows PowerShell `New-Item terraform.tfvars`
4. Substitute your AWS Access Key and Secret Key for the variables `access_key = {{ YOUR_ACCESS_KEY }}` and `secret_key = {{ YOUR_SECRET_KEY }}`. The terraform.tfvars.example file is included for your reference on what is needed.
3. Run `terraform init`
4. Run `terraform plan`
5. Run `terraform apply --auto-approve`

## Validation

1. SSH to the server using the Public IP Address created with the Elastic IP through the console and the user Ubuntu. A private SSH key is created in the `assets` directory that is created during provisioning. Use the SSH key `netspi_key`. Example: `ssh -i netspi_key ubuntu@{{ PUBLIC_IP_ADDRESS }}`. This meets Condition 1.

2. Condition 2 is met in through the `null_resource.configure_efs` terraform resource. This block configures the server with the tools necessary to mount the EFS and automatically remount it on boot.

3. Condition 3 is met through by testing that we can write to /data/test, which can be accomplished while SSHed to the server and running the command `echo "Hello, World!" > /data/test/test.txt` and then `ls -l /data/test`, and then we should be able to see the new text file in /data/test.

4. Condition 4 is met through IAM role attached to the server. To validate that we can write data to the provisioned S3 bucket we can run through the following commands: `echo "This is a test upload file!" > test.txt` and then we can upload the file to the s3 bucket using the aws cli command `aws s3 cp test.txt s3://netspi-challenge-bucket`. It should return `upload: ./test.txt to s3://netspi-challenge-bucket/test.txt`, but to double validate, we can run the aws cli command: `aws s3 ls s3://netspi-challenge-bucket` which will return something similar to `2023-03-02 18:18:51         13 test.txt`.

5. Condition 5 is met in the `outputs.tf` file. The S3 Bucket ID is outputed by `s3_bucket_id`, EFS Volume ID by `efs_id`, EC2 Instance ID by `instance_id`, Security Group ID by `security_group_ids`, and Subnet ID by `subnet_id`.