#!/bin/bash
set -e

cat > /etc/boundary/controller.hcl <<EOF
disable_mlock = true

controller {
  name        = "main_controller"
  description = "Controller utama untuk infrastruktur."
}

listener "tcp" {
  address = "0.0.0.0:9200"
  purpose = "api"
}

database {
  url = "${db_connection_string}"
}
EOF
