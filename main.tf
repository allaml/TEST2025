
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Use data source to get the NetApp FSx VPCID/VPCNAME/STATE based on the tag filter, to inject dynamically into security group resource creation.
# data "aws_vpc" "sddc_vpc_info" {
#   filter {
#     name   = "tag:Name"
#     values = ["hoag-${var.project_name}-${var.environment}-${var.sharetype}-vpc"] # Replace with your VPC name pattern if VPC already exist.
#   }

#   filter {
#     name   = "tag:Project"
#     values = [var.project_name]
#   }

#   filter {
#     name   = "tag:Environment"
#     values = [var.environment]
#   }

#   filter {
#     name   = "state"
#     values = ["available"]
#   }
# }
# Data source: Fetching private subnets private2-2a/private2-2b from the VPC to accomdate IPs for EC2 instances.
data "aws_subnets" "az_subnets_info" {
  # filter {
  #   name   = "vpc-id"
  #   values = [vpc-0b3c68972bc65c0a3]  #[data.aws_vpc.sddc_vpc_info.id]
  # }

  filter {
    name   = "tag:Name"
    values = ["*private2-2*"]
  }
}

data "aws_subnet" "subnet_details" {
  for_each = toset(data.aws_subnets.az_subnets_info.ids)
  id       = each.value
}

# Data source to fetch existing IAM role
data "aws_iam_role" "ec2_role" {
  name = "AmazonSSMRoleForInstancesQuickSetup"
}

# Data source to fetch existing instance profile (if it exists)
data "aws_iam_instance_profile" "InstancesQuickSetup_profile" {
  name = "AmazonSSMRoleForInstancesQuickSetup"
}

data "aws_ssm_parameter" "windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

# Local variables
locals {
  # EC2 Extraction for Email Notification.
  instance_details = {
    for k, v in aws_instance.muvservers : k => {
      name          = v.tags["Name"]
      id            = v.id
      private_ip    = v.private_ip
      instance_type = v.instance_type
      subnet_id     = v.subnet_id
      environment   = v.tags["Environment"]
      az            = v.availability_zone
    }
  }

  email_recipients = [
    "murthysai.allam@hoag.org",
    # "recipient2@domain.com",
    # "recipient3@domain.com"
  ]
  # Split instances between blue and green
  blue_instances  = [for idx in range(var.instance_count): idx if idx % 2 == 0]
  green_instances = [for idx in range(var.instance_count): idx if idx % 2 == 1]

  # Create a map of instance names with their corresponding numbers
  instance_names = {
    for idx in range(var.instance_count) :
    tostring(idx) => format("%s%02d", var.instance_name_prefix, idx + 1)
  }

  # Get instance type based on environment and size
  instance_config = {
    for idx in range(var.instance_count) : 
    tostring(idx) => {
      name          = local.instance_names[tostring(idx)]
      instance_type = var.instance_type_mapping[var.environment][var.instance_size]
      role          = var.instance_type_mapping[var.environment].role
      environment   = var.environment
      deployment    = contains(local.blue_instances, idx) ? "blue" : "green"
      volume_size   = var.volume_size_mapping[var.environment][var.instance_size]
      tags = merge(var.global_tags, {
        Name        = local.instance_names[tostring(idx)]
        Environment = var.environment
        Deployment  = contains(local.blue_instances, idx) ? "blue" : "green"
      })
    }
  }

  ad_credentials = jsondecode(data.aws_secretsmanager_secret_version.winsrv_ad.secret_string)
  domain_name    = upper(local.ad_credentials["domain_name"])
  domain_ou      = "OU=AWS Servers,OU=Server Resources,OU=OPERATIONS,DC=hoag,DC=org"
  username       = local.ad_credentials["username"]
  password       = local.ad_credentials["password"]
  dns_ips_list   = [local.ad_credentials["dns_ips_list"]]

  # AMI mapping with validation
  ami_mapping = {
    for env in ["dev", "prod"] : env => data.aws_ssm_parameter.windows_ami.value
  }
  # instance_volume_sizes = {
  #   for k, v in var.ec2_instances : k => lookup(var.volume_size_mapping[var.environment],
  #     v.size,
  #     var.volume_size # fallback to default if size not found
  #   )
  # }
  # Create a map of AZ to subnet ID
  subnets_by_az = {
    for subnet_id, subnet in data.aws_subnet.subnet_details :
    subnet.availability_zone => subnet_id
  }
  # Map instances to subnets
  instance_subnet_mapping = {
    for idx in range(var.instance_count) : 
    tostring(idx) => {
      subnet_id = local.subnets_by_az[sort(keys(local.subnets_by_az))[idx % length(local.subnets_by_az)]]
      az_name   = sort(keys(local.subnets_by_az))[idx % length(local.subnets_by_az)]
      private_ip = cidrhost(
        data.aws_subnet.subnet_details[
          local.subnets_by_az[sort(keys(local.subnets_by_az))[idx % length(local.subnets_by_az)]]
        ].cidr_block,
        idx + 10
      )
    }
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "ec2-private-sg-app01"
  description = "Security group for private EC2 instances"
  vpc_id      = "vpc-0b3c68972bc65c0a3" #""vpc-0b3c68972bc65c0a3" #data.aws_vpc.sddc_vpc_info.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from all traffic"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from ALB"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from ALB"
  }
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow RDP from Bastion"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "ec2-priv-sg-muv"
    Environment = "prod"
    Terraform   = "true"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Data source 05: Extracting/retrieving the username and password for the "DOMAIN CONTROLLER" from AWS secrets manager service
data "aws_secretsmanager_secret" "winsrv_ad" {
  name = var.winsrvad_secret_name
}

data "aws_secretsmanager_secret_version" "winsrv_ad" {
  secret_id = data.aws_secretsmanager_secret.winsrv_ad.id
}

# EC2 Instances in private subnets
resource "aws_instance" "muvservers" {
  for_each               = local.instance_config
  ami                    = local.ami_mapping[var.environment]
  instance_type          = each.value.instance_type
  subnet_id              = local.instance_subnet_mapping[each.key].subnet_id
  # private_ip             = local.instance_subnet_mapping[each.key].private_ip
  iam_instance_profile   = each.value.role #data.aws_iam_instance_profile.InstancesQuickSetup_profile.name
  vpc_security_group_ids = ["sg-06246b23d962c36f7", aws_security_group.ec2.id]   #[aws_security_group.ec2.id]
  user_data = templatefile("${path.module}/userdata.ps1", {
    domain_name  = local.domain_name
    instance_name = each.value.name
    oupath       = local.domain_ou
    secretid     = data.aws_secretsmanager_secret_version.winsrv_ad.secret_id
  })
  
  # Preconditions to check for Instance types and subnet availability based on the filters
  lifecycle {
    precondition {
      condition     = contains(var.allowed_instance_types, each.value.instance_type)
      error_message = "Invalid instance type '${each.value.instance_type}'. Must contains: ${join(", ", var.allowed_instance_types)}"
    }
    precondition {
      condition     = length(local.subnets_by_az) > 0
      error_message = "No subnets found.Validate subnet filters and VPC configuration."
    }

    precondition {
      condition     = contains(keys(local.instance_subnet_mapping), each.key)
      error_message = "No subnet mapping found for instance ${each.key}"
    }
  }
  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.volume_size_mapping[var.environment][var.instance_size]
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name        = "${each.value.name}-root-volume"
      Environment = each.value.environment
    }
  }
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = var.volume_size_mapping[var.environment][var.instance_size]
    volume_type = "gp3"
    encrypted   = true

    tags = merge(
      var.global_tags,
      {
        Name = "${each.value.name}-data-volume"
      }
    )
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  monitoring = true
  tags = merge(
    var.global_tags,
    {
      Name        = each.value.name
      Environment = each.value.environment
      Role        = each.value.role
      Terraform   = "true"
      AZ = local.instance_subnet_mapping[each.key].az_name
    }
  )

}

resource "aws_sns_topic" "ec2_completion" {
  name = "ec2-deployment-completion-notification"

  tags = {
    Name        = "EC2 Deployment Notifications"
    Environment = var.environment
  }
}

# SNS Topic Subscription to the given distribution list
resource "aws_sns_topic_subscription" "ec2_completion_email" {
  topic_arn = aws_sns_topic.ec2_completion.arn
  protocol  = "email"
  endpoint  = "murthysai.allam@hoag.org"
}

# Resource: Null resource to check the status of the instances. Terraform exiting out even if one instance is not ready and Initializing Phase.
resource "null_resource" "wait_for_instance_ready" {
  for_each = aws_instance.muvservers

  triggers = {
    instance_id = each.value.id
    user_data   = each.value.user_data
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass"]
    command     = "& '${path.module}/check_instance_status.ps1' -InstanceId '${each.value.id}' -Region '${data.aws_region.current.name}'"
    quiet       = true
  }

  depends_on = [aws_instance.muvservers]
}

resource "null_resource" "status_message" {
  provisioner "local-exec" {
    command     = "Write-Host 'Checking status for ${length(aws_instance.muvservers)} instances.'"
    interpreter = ["PowerShell", "-Command"]
    quiet       = true
  }
  depends_on = [aws_instance.muvservers]
}

# resource "null_resource" "completion_message" {
#   provisioner "local-exec" {
#     command     = "Write-Host 'All instances are ready and passed status checks!'"
#     interpreter = ["PowerShell", "-Command"]
#     quiet       = true
#   }
#   depends_on = [null_resource.wait_for_instance_ready]
# }

#======

resource "null_resource" "send_detailed_completion_email" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<EOT
try {
    $deploymentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $message = @"
***************************************************************************
*   🔵 EC2 Deployment completion notification                             *
***************************************************************************

***********************************
* 📊 Infrastructure Information   *
***********************************
🌐 Environment:     ${var.environment}
📍 Region:           ${data.aws_region.current.name}
📦 Total Instances: ${length(local.instance_details)}

****************************************
*  🖥️ EC2 Instance Details             *
****************************************
${join("\n\n", [
    for k, instance in local.instance_details : <<-INSTANCE
┌────────────────────────────────────────┐
│ Instance: ${instance.name}             
│ ▪ ID: ${instance.id}                   
│ ▪ Private IP: ${instance.private_ip}
│ ▪ Instance Type: ${instance.instance_type}
│ ▪ Subnet ID: ${instance.subnet_id}
│ ▪ Environment: ${instance.environment}
│ ▪ Availability Zone: ${instance.az}
└────────────────────────────────────────┘
INSTANCE
    ])}

****************************************
* 📋 Infrastructure Information        *
****************************************
🕒 Deployment Time: $deploymentTime

**************************************
* ✅ Status checks                  *
**************************************
✓ All instances are running
✓ Health checks passed
✓ Domain join completed successfully

*******************************************
* 📊 Health Check Information             *
*******************************************
✓ EC2 instances health check passed
✓ All components are accessible

*************************************************
* ⚠️ Important Notes & reminders  
*************************************************
• Please allow up to 15 minutes for all services to be fully operational
• Verify all instances are accessible
• Check monitoring dashboards for performance metrics
• Confirm DNS resolution is working as expected

********************************
*   🔍 Post Validation Steps   *
********************************
1. Verify ec2 Instances accessibility
2. Run application software and perform tests
4. Contact Cloud Engineering Team for any certificate needs or issues

****************************************************
* EC2 Instrastructure is built by Terraform Automation *
* 📅 $deploymentTime    *
****************************************************

"@

    # Normalize line endings while preserving empty lines
    $message = $message -replace "`r`n", "`n"
    $message = $message -replace "`r", "`n"
    $message = $message -replace "(?<!\n)\n(?!\n)", "`n"
    
    Write-Host "Sending SNS notification..."
    
    # Send SNS message directly with proper escaping
    $awsCommand = "aws sns publish --topic-arn `"${aws_sns_topic.ec2_completion.arn}`" --subject `"Hoag:EC2 Fleet Deployment Complete - ${var.environment}`" --message `"$($message -replace '"', '\"')`""
    $result = Invoke-Expression $awsCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ SNS notification sent successfully"
        Write-Host $result
    } else {
        Write-Error "❌ Failed to send SNS notification: $result"
        exit 1
    }
} catch {
    Write-Error "❌ Exception occurred: $_"
    exit 1
}
EOT
  }

  depends_on = [
    time_sleep.wait_01_minutes,
    null_resource.completion_message,
    aws_sns_topic_subscription.ec2_completion_email,
    aws_instance.muvservers,
    aws_sns_topic.ec2_completion
  ]

  triggers = {
    instance_ids = join(",", [for k, v in aws_instance.muvservers : v.id])
    timestamp    = timestamp()
  }
}

# Resource: Null resource to check the status of the instances. Terraform exits out even if one instance is not ready.
# resource "null_resource" "wait_for_instance_ready" {
#   for_each = aws_instance.muvservers
#   triggers = {
#     instance_id = each.value.id
#     user_data   = each.value.user_data
#   }
#   provisioner "local-exec" {
#     interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass"]
#     command     = "& '${path.module}/check_instance_status.ps1' -InstanceId '${each.value.id}' -Region '${data.aws_region.current.name}'"
#     quiet       = true
#   }
#   depends_on = [aws_instance.muvservers]
# }

# resource "null_resource" "status_message" {
#   provisioner "local-exec" {
#     command     = "Write-Host 'Checking status for ${length(aws_instance.muvservers)} instances.'"
#     interpreter = ["PowerShell", "-Command"]
#     quiet       = true
#   }
#   depends_on = [aws_instance.muvservers]
# }

# Add a 05-minute wait time
resource "time_sleep" "wait_01_minutes" {
  create_duration = "60s"
  depends_on      = [null_resource.wait_for_instance_ready]

  triggers = {
    start_time = timestamp()
  }
}

resource "null_resource" "completion_message" {
  provisioner "local-exec" {
    command     = <<EOT
      Write-Host "Starting 05-minutes wait at $(Get-Date)"
      Start-Sleep -Seconds 300
      Write-Host "05-minutes wait completed successfully at $(Get-Date)"
      Write-Host 'All instances are ready and passed status checks!'
    EOT
    interpreter = ["PowerShell", "-Command"]
    quiet       = true
  }
  depends_on = [time_sleep.wait_01_minutes]
}





