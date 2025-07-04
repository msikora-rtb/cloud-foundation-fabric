/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "access_config" {
  description = "Control plane endpoint and nodes access configurations."
  type = object({
    dns_access = optional(bool, true)
    ip_access = optional(object({
      authorized_ranges                              = optional(map(string))
      disable_public_endpoint                        = optional(bool)
      gcp_public_cidrs_access_enabled                = optional(bool)
      private_endpoint_authorized_ranges_enforcement = optional(bool)
      private_endpoint_config = optional(object({
        endpoint_subnetwork = optional(string)
        global_access       = optional(bool, true)
      }))
    }))
    master_ipv4_cidr_block = optional(string)
    private_nodes          = optional(bool, true)
  })
  nullable = false
  default  = {}
  validation {
    condition = (
      try(var.access_config.ip_access.disable_public_endpoint, null) != true ||
      var.access_config.private_nodes == true
    )
    error_message = "Private endpoint can only be enabled with private nodes."
  }
}

variable "backup_configs" {
  description = "Configuration for Backup for GKE."
  type = object({
    enable_backup_agent = optional(bool, false)
    backup_plans = optional(map(object({
      region                            = string
      applications                      = optional(map(list(string)))
      encryption_key                    = optional(string)
      include_secrets                   = optional(bool, true)
      include_volume_data               = optional(bool, true)
      labels                            = optional(map(string))
      namespaces                        = optional(list(string))
      schedule                          = optional(string)
      retention_policy_days             = optional(number)
      retention_policy_lock             = optional(bool, false)
      retention_policy_delete_lock_days = optional(number)
    })), {})
  })
  default  = {}
  nullable = false
}

variable "cluster_autoscaling" {
  description = "Enable and configure limits for Node Auto-Provisioning with Cluster Autoscaler."
  type = object({
    enabled             = optional(bool, true)
    autoscaling_profile = optional(string, "BALANCED")
    auto_provisioning_defaults = optional(object({
      boot_disk_kms_key = optional(string)
      disk_size         = optional(number)
      disk_type         = optional(string, "pd-standard")
      image_type        = optional(string)
      oauth_scopes      = optional(list(string))
      service_account   = optional(string)
      management = optional(object({
        auto_repair  = optional(bool, true)
        auto_upgrade = optional(bool, true)
      }))
      shielded_instance_config = optional(object({
        integrity_monitoring = optional(bool, true)
        secure_boot          = optional(bool, false)
      }))
      upgrade_settings = optional(object({
        blue_green = optional(object({
          node_pool_soak_duration = optional(string)
          standard_rollout_policy = optional(object({
            batch_percentage    = optional(number)
            batch_node_count    = optional(number)
            batch_soak_duration = optional(string)
          }))
        }))
        surge = optional(object({
          max         = optional(number)
          unavailable = optional(number)
        }))
      }))
      # add validation rule to ensure only one is present if upgrade settings is defined
    }))
    auto_provisioning_locations = optional(list(string))
    cpu_limits = optional(object({
      min = optional(number, 0)
      max = number
    }))
    mem_limits = optional(object({
      min = optional(number, 0)
      max = number
    }))
    accelerator_resources = optional(list(object({
      resource_type = string
      min           = optional(number, 0)
      max           = number
    })))
  })
  default = null
  validation {
    condition = (var.cluster_autoscaling == null ? true : contains(
      ["BALANCED", "OPTIMIZE_UTILIZATION"],
      var.cluster_autoscaling.autoscaling_profile
    ))
    error_message = "Invalid autoscaling_profile."
  }
  validation {
    condition = (
      try(var.cluster_autoscaling, null) == null ||
      try(var.cluster_autoscaling.auto_provisioning_defaults, null) == null ? true : contains(
        ["pd-standard", "pd-ssd", "pd-balanced"],
      var.cluster_autoscaling.auto_provisioning_defaults.disk_type)
    )
    error_message = "Invalid disk_type."
  }
  validation {
    condition = (
      try(var.cluster_autoscaling.upgrade_settings, null) == null || (
        try(var.cluster_autoscaling.upgrade_settings.blue_green, null) == null ? 0 : 1
        +
        try(var.cluster_autoscaling.upgrade_settings.surge, null) == null ? 0 : 1
      ) == 1
    )
    error_message = "Upgrade settings can only use blue/green or surge."
  }
}

variable "default_nodepool" {
  description = "Enable default nodepool."
  type = object({
    remove_pool        = optional(bool, true)
    initial_node_count = optional(number, 1)
  })
  default  = {}
  nullable = false
  validation {
    condition = (
      var.default_nodepool.remove_pool != true
      ||
      var.default_nodepool.initial_node_count != null
    )
    error_message = "If `remove_pool` is set to false, `initial_node_count` needs to be set."
  }
}

variable "deletion_protection" {
  description = "Whether or not to allow Terraform to destroy the cluster. Unless this field is set to false in Terraform state, a terraform destroy or terraform apply that would delete the cluster will fail."
  type        = bool
  default     = true
  nullable    = false
}

variable "description" {
  description = "Cluster description."
  type        = string
  default     = null
}

variable "enable_addons" {
  description = "Addons enabled in the cluster (true means enabled)."
  type = object({
    cloudrun                       = optional(bool, false)
    config_connector               = optional(bool, false)
    dns_cache                      = optional(bool, true)
    gce_persistent_disk_csi_driver = optional(bool, true)
    gcp_filestore_csi_driver       = optional(bool, true)
    gcs_fuse_csi_driver            = optional(bool, true)
    horizontal_pod_autoscaling     = optional(bool, true)
    http_load_balancing            = optional(bool, true)
    istio = optional(object({
      enable_tls = bool
    }))
    kalm           = optional(bool, false)
    network_policy = optional(bool, false)
    stateful_ha    = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "enable_features" {
  description = "Enable cluster-level features. Certain features allow configuration."
  type = object({
    beta_apis                         = optional(list(string))
    binary_authorization              = optional(bool, false)
    cilium_clusterwide_network_policy = optional(bool, false)
    cost_management                   = optional(bool, true)
    dns = optional(object({
      additive_vpc_scope_dns_domain = optional(string)
      provider                      = optional(string)
      scope                         = optional(string)
      domain                        = optional(string)
    }))
    multi_networking = optional(bool, false)
    database_encryption = optional(object({
      state    = string
      key_name = string
    }))
    dataplane_v2          = optional(bool, true)
    fqdn_network_policy   = optional(bool, true)
    gateway_api           = optional(bool, false)
    groups_for_rbac       = optional(string)
    image_streaming       = optional(bool, false)
    intranode_visibility  = optional(bool, false)
    l4_ilb_subsetting     = optional(bool, false)
    mesh_certificates     = optional(bool)
    pod_security_policy   = optional(bool, false)
    secret_manager_config = optional(bool)
    security_posture_config = optional(object({
      mode               = string
      vulnerability_mode = string
    }))
    resource_usage_export = optional(object({
      dataset                              = string
      enable_network_egress_metering       = optional(bool)
      enable_resource_consumption_metering = optional(bool)
    }))
    service_external_ips = optional(bool, true)
    shielded_nodes       = optional(bool, false)
    tpu                  = optional(bool, false)
    upgrade_notifications = optional(object({
      topic_id = optional(string)
    }))
    vertical_pod_autoscaling = optional(bool, false)
    workload_identity        = optional(bool, true)
    enterprise_cluster       = optional(bool)
  })
  default = {}
  validation {
    condition = (
      var.enable_features.fqdn_network_policy ? var.enable_features.dataplane_v2 : true
    )
    error_message = "FQDN network policy is only supported for clusters with Dataplane v2."
  }
}

variable "issue_client_certificate" {
  description = "Enable issuing client certificate."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Cluster resource labels."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "location" {
  description = "Cluster zone or region."
  type        = string
}

variable "logging_config" {
  description = "Logging configuration."
  type = object({
    enable_system_logs             = optional(bool, true)
    enable_workloads_logs          = optional(bool, false)
    enable_api_server_logs         = optional(bool, false)
    enable_scheduler_logs          = optional(bool, false)
    enable_controller_manager_logs = optional(bool, false)
  })
  default  = {}
  nullable = false
  # System logs are the minimum required component for enabling log collection.
  # So either everything is off (false), or enable_system_logs must be true.
  validation {
    condition = (
      !anytrue(values(var.logging_config)) || var.logging_config.enable_system_logs
    )
    error_message = "System logs are the minimum required component for enabling log collection."
  }
}

variable "maintenance_config" {
  description = "Maintenance window configuration."
  type = object({
    daily_window_start_time = optional(string)
    recurring_window = optional(object({
      start_time = string
      end_time   = string
      recurrence = string
    }))
    maintenance_exclusions = optional(list(object({
      name       = string
      start_time = string
      end_time   = string
      scope      = optional(string)
    })))
  })
  default = {
    daily_window_start_time = "03:00"
    recurring_window        = null
    maintenance_exclusion   = []
  }
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per node in this cluster."
  type        = number
  default     = 110
}

variable "min_master_version" {
  description = "Minimum version of the master, defaults to the version of the most recent official release."
  type        = string
  default     = null
}

variable "monitoring_config" {
  description = "Monitoring configuration. Google Cloud Managed Service for Prometheus is enabled by default."
  type = object({
    enable_system_metrics = optional(bool, true)
    # Control plane metrics
    enable_api_server_metrics         = optional(bool, false)
    enable_controller_manager_metrics = optional(bool, false)
    enable_scheduler_metrics          = optional(bool, false)
    # Kube state metrics
    enable_daemonset_metrics   = optional(bool, false)
    enable_deployment_metrics  = optional(bool, false)
    enable_hpa_metrics         = optional(bool, false)
    enable_pod_metrics         = optional(bool, false)
    enable_statefulset_metrics = optional(bool, false)
    enable_storage_metrics     = optional(bool, false)
    enable_cadvisor_metrics    = optional(bool, false)
    # Google Cloud Managed Service for Prometheus
    enable_managed_prometheus = optional(bool, true)
    advanced_datapath_observability = optional(object({
      enable_metrics = bool
      enable_relay   = bool
    }))
  })
  default  = {}
  nullable = false
  validation {
    condition = anytrue([
      var.monitoring_config.enable_api_server_metrics,
      var.monitoring_config.enable_controller_manager_metrics,
      var.monitoring_config.enable_scheduler_metrics,
      var.monitoring_config.enable_daemonset_metrics,
      var.monitoring_config.enable_deployment_metrics,
      var.monitoring_config.enable_hpa_metrics,
      var.monitoring_config.enable_pod_metrics,
      var.monitoring_config.enable_statefulset_metrics,
      var.monitoring_config.enable_storage_metrics,
      var.monitoring_config.enable_cadvisor_metrics,
    ]) ? var.monitoring_config.enable_system_metrics : true
    error_message = "System metrics are the minimum required component for enabling metrics collection."
  }
  validation {
    condition = anytrue([
      var.monitoring_config.enable_daemonset_metrics,
      var.monitoring_config.enable_deployment_metrics,
      var.monitoring_config.enable_hpa_metrics,
      var.monitoring_config.enable_pod_metrics,
      var.monitoring_config.enable_statefulset_metrics,
      var.monitoring_config.enable_storage_metrics,
      var.monitoring_config.enable_cadvisor_metrics,
    ]) ? var.monitoring_config.enable_managed_prometheus : true
    error_message = "Kube state metrics collection requires Google Cloud Managed Service for Prometheus to be enabled."
  }
}

variable "name" {
  description = "Cluster name."
  type        = string
}

variable "node_config" {
  description = "Node-level configuration."
  type = object({
    boot_disk_kms_key             = optional(string)
    k8s_labels                    = optional(map(string))
    labels                        = optional(map(string))
    service_account               = optional(string)
    tags                          = optional(list(string))
    workload_metadata_config_mode = optional(string)
    kubelet_readonly_port_enabled = optional(bool, true)
  })
  default  = {}
  nullable = false
  validation {
    condition = contains(
      ["GCE_METADATA", "GKE_METADATA", "null"],
      coalesce(var.node_config.workload_metadata_config_mode, "null")
    )
    error_message = "node_config.workload_metadata_config_mode must be GCE_METADATA or GKE_METADATA."
  }
}

variable "node_locations" {
  description = "Zones in which the cluster's nodes are located."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "project_id" {
  description = "Cluster project id."
  type        = string
}

variable "release_channel" {
  description = "Release channel for GKE upgrades."
  type        = string
  default     = null
}

variable "vpc_config" {
  description = "VPC-level configuration."
  type = object({
    disable_default_snat = optional(bool)
    network              = string
    subnetwork           = string
    secondary_range_blocks = optional(object({
      pods     = string
      services = string
    }))
    secondary_range_names = optional(object({
      pods     = optional(string)
      services = optional(string)
    }))
    additional_ranges = optional(list(string))
    stack_type        = optional(string)
  })
  nullable = false
}
