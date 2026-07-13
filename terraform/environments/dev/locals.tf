locals {
  environment_name = terraform.workspace == "default" ? var.environment_name : terraform.workspace
  name_prefix      = "${var.project_name}-${local.environment_name}"

  common_tags = {
    Project     = var.project_name
    Environment = local.environment_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Scope       = "environment"
  }

  public_subnets = {
    for index, availability_zone in var.availability_zones : availability_zone => {
      cidr = var.public_subnet_cidrs[index]
      tier = index + 1
    }
  }

  kubernetes_nodes = {
    control-plane-1 = {
      availability_zone = var.availability_zones[0]
      instance_type     = var.control_plane_instance_type
      volume_size       = var.control_plane_volume_size
      role              = "control-plane"
      workload          = "platform"
      node_labels       = ""
      node_taints       = ""
    }
    worker-platform-1 = {
      availability_zone = var.availability_zones[0]
      instance_type     = var.platform_worker_instance_type
      volume_size       = var.platform_worker_volume_size
      role              = "worker"
      workload          = "platform"
      node_labels       = "role=platform medikong.io/workload=platform"
      node_taints       = ""
    }
    worker-app-1 = {
      availability_zone = var.availability_zones[1]
      instance_type     = var.app_worker_instance_types[0]
      volume_size       = var.app_worker_volume_sizes[0]
      role              = "worker"
      workload          = "app"
      node_labels       = "role=app medikong.io/workload=app"
      node_taints       = ""
    }
    worker-app-2 = {
      availability_zone = var.availability_zones[2]
      instance_type     = var.app_worker_instance_types[1]
      volume_size       = var.app_worker_volume_sizes[1]
      role              = "worker"
      workload          = "app"
      node_labels       = "role=app medikong.io/workload=app"
      node_taints       = ""
    }
    worker-data-1 = {
      availability_zone = var.availability_zones[1]
      instance_type     = var.data_worker_instance_types[0]
      volume_size       = var.data_worker_volume_sizes[0]
      role              = "worker"
      workload          = "data"
      node_labels       = "role=data medikong.io/workload=data"
      node_taints       = ""
    }
    worker-data-2 = {
      availability_zone = var.availability_zones[2]
      instance_type     = var.data_worker_instance_types[1]
      volume_size       = var.data_worker_volume_sizes[1]
      role              = "worker"
      workload          = "data"
      node_labels       = "role=data medikong.io/workload=data"
      node_taints       = ""
    }
    worker-observability-1 = {
      availability_zone = var.availability_zones[0]
      instance_type     = var.observability_worker_instance_type
      volume_size       = var.observability_worker_volume_size
      role              = "worker"
      workload          = "observability"
      node_labels       = "role=observability medikong.io/workload=observability"
      node_taints       = "medikong.io/workload=observability:NoSchedule"
    }
  }

  operator_public_key = var.public_key_path == null ? null : file(pathexpand(var.public_key_path))
}
