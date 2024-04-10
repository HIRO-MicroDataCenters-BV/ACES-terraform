variable "cluster_name" {}
variable "instance_type" {}
variable "num_workers" {}
variable "pod_network_cidr_block" {}
variable "service_cidr_block" {}
variable "ami" {}

module "kubernetes_cluster" {
  source = "github.com/RyaxTech/terraform-aws-kubeadm"

  cluster_name           = var.cluster_name
  master_instance_type   = var.instance_type
  worker_instance_type   = var.instance_type
  num_workers            = var.num_workers
  pod_network_cidr_block = var.pod_network_cidr_block
  service_cidr_block     = var.service_cidr_block
}

resource "kubernetes_config_map" "node_configuration_script" {
  metadata {
    name = "node-configuration-script-${var.cluster_name}"
  }

  data = {
    "create-var-partition.sh" = <<-EOT
      #!/usr/bin/env bash
      set -x
      set -u
      set -e

      if $(mountpoint /var -q)
      then
          echo "/var is already mounted! Exiting..."
          exit 0
      fi
      DEVICE=$${1:-/dev/nvme1n1}

      parted --script "$DEVICE" \\
          mklabel msdos \\
          mkpart primary 2MiB 100%

      mkfs.ext4 $${DEVICE}p1
      e2label $${DEVICE}p1 VAR

      mkdir /var2
      mount $${DEVICE}p1 /var2
      rsync -a /var/ /var2

      cat >> /etc/fstab <<EOF
      LABEL=VAR /var ext4 defaults 0 2
      EOF

      echo "/var configuration done! Rebooting..."
      reboot
    EOT
  }
}

resource "kubernetes_daemonset" "node_configurator" {
  metadata {
    name = "node-configurator-${var.cluster_name}"
  }

  spec {
    selector {
      match_labels = {
        name = "node-configurator"
      }
    }

    template {
      metadata {
        labels = {
          name = "node-configurator"
        }
      }

      spec {
        host_pid = true
        host_ipc = true
        host_network = true

        container {
          image = "alpine"
          name  = "configurator"

          security_context {
            privileged = true
          }

          volume_mount {
            name       = "host-root"
            mount_path = "/host"
          }

          volume_mount {
            name       = "node-configuration-script"
            mount_path = "/scripts"
          }

          command = ["nsenter"]
          args    = ["--target", "1", "--mount", "--", "bash", "/create-var-partition.sh"]
        }

        volume {
          name = "host-root"

          host_path {
            path = "/"
          }
        }

        volume {
          name = "node-configuration-script"

          config_map {
            name = kubernetes_config_map.node_configuration_script.metadata[0].name
          }
        }
      }
    }
  }
} 

