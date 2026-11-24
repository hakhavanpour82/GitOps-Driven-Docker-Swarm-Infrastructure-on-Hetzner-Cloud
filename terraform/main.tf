locals {
  servers = {
    nginx      = { ip = "192.168.100.10", type = var.size_small, role = "edge" }
    app1       = { ip = "192.168.100.21", type = var.size_small, role = "app" }
    app2       = { ip = "192.168.100.22", type = var.size_small, role = "app" }
    portainer  = { ip = "192.168.100.30", type = var.size_small, role = "manager" }
    runner     = { ip = "192.168.100.31", type = var.size_medium, role = "runner" }
    monitoring = { ip = "192.168.100.40", type = var.size_small, role = "monitoring" }
    elk        = { ip = "192.168.100.50", type = var.size_medium, role = "logging" }
    mongodb    = { ip = "192.168.100.60", type = var.size_small, role = "db" }
  }

  labels = {
    project = "applyops"
    env     = "prod"
  }

  admin_ssh_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  cf_ips = concat(
    split("\n", trimspace(data.http.cf_v4.response_body)),
    split("\n", trimspace(data.http.cf_v6.response_body))
  )

  # Clean, deduplicated rules for internal firewall
  internal_rules = {
    ssh_admin = {
      port        = "22"
      source_ips  = [local.admin_ssh_cidr]
      description = "SSH from admins"
    }
    portainer_ui = {
      port        = "9443"
      source_ips  = var.admin_cidrs
      description = "Portainer UI"
    }
    grafana_admin = {
      port        = "3000"
      source_ips  = var.admin_cidrs
      description = "Grafana UI from admins"
    }
    kibana_admin = {
      port        = "5601"
      source_ips  = var.admin_cidrs
      description = "Kibana UI from admins"
    }
    node_exporter = {
      port        = "9100"
      source_ips  = ["192.168.100.40/32"]
      description = "Node Exporter from Monitoring"
    }
    cadvisor = {
      port        = "8081"
      source_ips  = ["192.168.100.40/32"]
      description = "cAdvisor from Monitoring"
    }
    grafana_nginx = {
      port        = "3000"
      source_ips  = ["192.168.100.10/32"]
      description = "Grafana from Nginx"
    }
    prometheus_nginx = {
      port        = "9090"
      source_ips  = ["192.168.100.10/32"]
      description = "Prometheus from Nginx"
    }
    alertmanager_nginx = {
      port        = "9093"
      source_ips  = ["192.168.100.10/32"]
      description = "Alertmanager from Nginx"
    }
    kibana_nginx = {
      port        = "5601"
      source_ips  = ["192.168.100.10/32"]
      description = "Kibana from Nginx"
    }
    elasticsearch_ingest = {
      port        = "9200"
      source_ips  = ["192.168.100.10/32", "192.168.100.21/32", "192.168.100.22/32"]
      description = "Elasticsearch ingest from Edge and App nodes"
    }
  }

  roles = distinct([for s in local.servers : s.role])
}

# ---------- External Data ----------
data "http" "my_ip" {
  url = "https://ifconfig.me"
}

data "http" "cf_v4" {
  url = "https://www.cloudflare.com/ips-v4"
}

data "http" "cf_v6" {
  url = "https://www.cloudflare.com/ips-v6"
}

# ---------- Network ----------
resource "hcloud_network" "main" {
  name     = "applyops-net"
  ip_range = "192.168.100.0/24"
}

resource "hcloud_network_subnet" "region1" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "192.168.100.0/24"
}

resource "hcloud_network_route" "default_nat" {
  network_id  = hcloud_network.main.id
  destination = "0.0.0.0/0"
  gateway     = "192.168.100.10"
}

# ---------- SSH Key ----------
resource "hcloud_ssh_key" "admin" {
  name       = "applyops-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
  labels     = local.labels
}

# ---------- Firewalls ----------
resource "hcloud_firewall" "edge" {
  name = "applyops-fw-edge"
  apply_to { label_selector = "project=applyops,role=edge" }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = local.cf_ips
    description = "HTTP from Cloudflare"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = local.cf_ips
    description = "HTTPS from Cloudflare"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = [local.admin_ssh_cidr]
    description = "SSH from admins"
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "27017"
    source_ips = ["192.168.100.21/32", "192.168.100.22/32"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "9216"
    source_ips = ["192.168.100.40/32"]
  }
  rule {
  direction  = "in"
  protocol   = "tcp"
  port       = "9091"
  source_ips = ["192.168.100.60/32"]
  }
}

resource "hcloud_firewall" "internal" {
  name = "applyops-fw-internal"
  apply_to { label_selector = "project=applyops,role!=edge" }

  dynamic "rule" {
    for_each = local.internal_rules
    content {
      direction   = "in"
      protocol    = "tcp"
      port        = rule.value.port
      source_ips  = rule.value.source_ips
      description = rule.value.description
    }
  }
}

# ---------- Servers ----------
resource "hcloud_server" "this" {
  for_each    = local.servers
  name        = "hz-de-dev-${each.key}"
  server_type = each.value.type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.admin.id]
  labels      = merge(local.labels, { role = each.value.role })

  public_net {
    ipv4_enabled = each.key == "nginx"
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.main.id
    ip         = each.value.ip
  }

  depends_on = [hcloud_network_subnet.region1]

  lifecycle {
    ignore_changes = [ssh_keys, image]
  }
}

# ---------- Ansible Inventory ----------
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = join("\n", concat(
    flatten([
      for r in local.roles : concat(
        ["[${r}]"],
        [for n, s in local.servers :
          n == "nginx"
          ? "${n} ansible_host=${hcloud_server.this[n].ipv4_address} private_ip=${s.ip} ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'"
          : "${n} ansible_host=${s.ip} private_ip=${s.ip}"
          if s.role == r
        ],
        [""]
      )
    ]),
    [
      "[all:vars]",
      "ansible_user=root",
      "ansible_ssh_private_key_file=~/.ssh/applyops_ed25519",
      "ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o ProxyCommand=\"ssh -i ~/.ssh/applyops_ed25519 -o StrictHostKeyChecking=accept-new -W %h:%p root@${hcloud_server.this["nginx"].ipv4_address}\"'",
      ""
    ]
  ))
}

