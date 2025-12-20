volume_size             = 30
environment             = "prod"
winsrvad_secret_name    = "hoagwinsrv-admin"
create_instance_profile = false
instance_name_prefix    = "app-prep"
instance_size            = "small"

instance_type_mapping = {
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

volume_size_mapping = {
  prod = {
    small  = 50
    medium = 100
    large  = 200
  }
  dev = {
    small  = 30
    medium = 50
    large  = 100
  }
}



