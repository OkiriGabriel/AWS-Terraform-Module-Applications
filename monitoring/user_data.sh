#!/bin/bash
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y docker.io git curl
  DOCKER_USER=ubuntu
elif command -v yum >/dev/null 2>&1; then
  yum update -y
  yum install -y docker git curl
  DOCKER_USER=ec2-user
else
  echo "user_data: no apt-get or yum; cannot install Docker" >&2
  exit 1
fi

systemctl start docker
systemctl enable docker
usermod -a -G docker "$DOCKER_USER"
