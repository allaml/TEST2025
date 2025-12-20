variable "global_tags" {
  type = map(string)
  default = {
    ResourceOwner            = "storage team"
    Notification             = "xxxx"
    CostCenter               = "1000-84800"
    DataClassification       = "Internal"
    Compliance               = "None"
    ApplicationId            = "007"
    Managed_By               = "terraform"
  }
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "HOAG.ORG"
}

# variable "app_name" {
#   description = "Primary application name"
#   type        = string
#   default     = "VNWD"
# }

variable "environment" {
  type    = string
  default = "prod"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either dev or prod."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "prod"
    Terraform   = "true"
  }
}

variable "instance_name_prefix" {
  description = "Prefix for instance names"
  type        = string
  default     = "VNWTTASRT"
}

variable "winsrvad_secret_name" {
  description = "Name of the secret containing domain join credentials"
  type        = string
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

# variable "ec2_instances" {
#   description = "Map EC2 instances with required configurations"
#   type = map(object({
#     name        = string
#     environment = string
#     role        = string
#     size        = string
#   }))

#   default = {
#     server1 = {
#       environment = "prod"
#       role        = "AmazonSSMRoleForInstancesQuickSetup"
#       size        = "medium"
#     },
#     server2 = {
#       environment = "prod"
#       role        = "AmazonSSMRoleForInstancesQuickSetup"
#       size        = "medium"
#     }
#   }

#   validation {
#     condition = alltrue([
#       for k, v in var.ec2_instances :
#       contains(["dev", "prod"], v.environment)
#     ])
#     error_message = "Environment must be either 'dev' or 'prod'."
#   }

#   validation {
#     condition = alltrue([
#       for k, v in var.ec2_instances :
#       contains(["small", "medium", "large"], v.size)
#     ])
#     error_message = "Size must be one of: 'small', 'medium', 'large'."
#   }
# }

variable "create_instance_profile" {
  description = "Whether to create a new instance profile"
  type        = bool
  default     = false
}

variable "instance_type_mapping" {
  description = "Map of environment to instance sizes"
  type = map(object({
    small  = string
    medium = string
    large  = string
    role   = string
  }))
  default = {
    prod = {
      small  = "t3.small"
      medium = "t3.medium"
      large  = "t3.large"
      role   = "AmazonSSMRoleForInstancesQuickSetup"
    }
    dev = {
      small  = "t3.medium"
      medium = "t3.large"
      large  = "t3.xlarge"
      role   = "AmazonSSMRoleForInstancesQuickSetup"
    }
  }
}

variable "instance_size" {
  description = "Size of the instance (small, medium, large)"
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["small", "medium", "large"], var.instance_size)
    error_message = "Instance size must be one of: small, medium, large"
  }
}

variable "allowed_instance_types" {
  description = "List of allowed EC2 instance types"
  type        = list(string)
  default = [
    "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge",
    "m5.large", "m5.xlarge", "m5.2xlarge"
  ]
}

variable "volume_size" {
  description = "Volume size for the EC2 instances"
  type        = string
  default     = 30
}

variable "volume_size_mapping" {
  description = "Map of instance sizes to their corresponding volume sizes"
  type        = map(map(number))
  default = {
    prod = {
      small  = 30
      medium = 50
      large  = 100
    }
    dev = {
      small  = 20
      medium = 30
      large  = 50
    }
  }
}

variable "deployment_mapping" {
  type = map(string)
  description = "Maps instance index to blue/green deployment"
  default = {
    "0" = "blue"
    "1" = "green"
    # Add more mappings as needed for the hoag app project requirements.
  }
}

variable "notification_email" {
  description = "Email address for deployment notifications"
  type        = string
  default     = "murthysai.allam@hoag.org"
}
