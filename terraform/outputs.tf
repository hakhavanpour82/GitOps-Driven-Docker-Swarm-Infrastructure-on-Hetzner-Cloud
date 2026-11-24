output "public_ips" {
  value = { for k, s in hcloud_server.this : k => s.ipv4_address }
}
