ui = true
disable_mlock = "true"

storage "raft" {
  path    = "/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address = "[::]:8200"
  tls_disable = "true"
}

api_addr = "http://vault1.poc.thecloudgarage.com:8200"
cluster_addr = "http://vault1.poc.thecloudgarage.com:8201"