output "latest_windows_ami_id" {
  description = "Latest Windows Server 2022 AMI ID"
  value       = data.aws_ssm_parameter.windows_ami.value
  sensitive   = true
}

output "windows_ami_details" {
  description = "All details of Windows Server 2022 AMI parameter"
  value = {
    id      = data.aws_ssm_parameter.windows_ami.id
    arn     = data.aws_ssm_parameter.windows_ami.arn
    name    = data.aws_ssm_parameter.windows_ami.name
    type    = data.aws_ssm_parameter.windows_ami.type
    value   = data.aws_ssm_parameter.windows_ami.value
    version = data.aws_ssm_parameter.windows_ami.version
  }
  sensitive = true
}

output "ami_mapping_by_environment" {
  description = "AMI mapping for each environment"
  value       = local.ami_mapping
  sensitive   = true
}

# output "instance_ami_details" {
#   description = "AMI details for each instance"
#   value = {
#     for k, v in var.ec2_instances : k => {
#       instance_name = v.name
#       ami_id        = data.aws_ssm_parameter.windows_ami.value
#       environment   = v.environment
#       role          = v.role
#     }
#   }
#   sensitive = true
# }

output "instance_summary" {
  description = "comprehensive instance summary for post validation"
  value = {
    for k, v in aws_instance.muvservers : k => {
      "Instance ID"   = v.id
      "Private IP"    = v.private_ip
      "Environment"   = v.tags["Environment"]
      "Name"          = v.tags["Name"]
      "AZ"            = v.availability_zone
      "Instance Type" = v.instance_type
    }
  }
}

output "network_info" {
  description = "Network information of all provisioned instances"
  value = {
    for k, v in aws_instance.muvservers : k => {
      private_ip        = v.private_ip
      subnet_id         = v.subnet_id
      security_groups   = v.vpc_security_group_ids
      availability_zone = v.availability_zone
      subnet_cidr       = data.aws_subnet.subnet_details[v.subnet_id].cidr_block
      subnet_name       = data.aws_subnet.subnet_details[v.subnet_id].tags["Name"]
    }
  }
}

output "role_details" {
  description = "Out of roles and policies Information"
  value = {
    role_name = data.aws_iam_role.ec2_role.name
    role_id   = data.aws_iam_role.ec2_role.id
    role_arn  = data.aws_iam_role.ec2_role.arn
    path      = data.aws_iam_role.ec2_role.path
  }
}

output "instance_profile_details" {
  description = "Details of the instance profile which is acting as a container for the role"
  value = {
    name = data.aws_iam_instance_profile.InstancesQuickSetup_profile.name
    arn  = data.aws_iam_instance_profile.InstancesQuickSetup_profile.arn
    id   = data.aws_iam_instance_profile.InstancesQuickSetup_profile.id
    role = data.aws_iam_instance_profile.InstancesQuickSetup_profile.role_name
  }
}

output "instance_status" {
  description = "Status of EC2 instances status. This is a post validation output"
  value = {
    for k, v in aws_instance.muvservers : k => {
      instance_id = v.id
      state       = v.instance_state
      status      = "All status checks passed (verified by wait command)"
    }
  }
  depends_on = [null_resource.wait_for_instance_ready]
}


output "domain_name" {
  description = "Domain name used for AD join"
  value       = local.domain_name
  sensitive   = true
}


