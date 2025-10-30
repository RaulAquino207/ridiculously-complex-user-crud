#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

APP_NAME="${APP_NAME}"
REGISTRY="${REGISTRY}"
USE_ECR="${USE_ECR}"
REGISTRY_USERNAME="${REGISTRY_USERNAME}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD}"
COMPOSE_B64="${COMPOSE_B64}"

echo "===== start user-data $(date -Is) ====="

mkdir -p /opt/app

echo "$COMPOSE_B64" | base64 -d > /opt/app/docker-compose.yml
chmod 0644 /opt/app/docker-compose.yml

echo "$COMPOSE_B64" | base64 -d > "/opt/app/docker-compose.${APP_NAME}.yml"
chmod 0644 "/opt/app/docker-compose.${APP_NAME}.yml"

cat >/usr/local/bin/app-compose-env.sh <<EOF
APP_NAME="${APP_NAME}"
REGISTRY="${REGISTRY}"
USE_ECR="${USE_ECR}"
REGISTRY_USERNAME="${REGISTRY_USERNAME}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD}"
EOF
chmod 0644 /usr/local/bin/app-compose-env.sh

cat >/usr/local/bin/install-docker.sh <<'EOS'
#!/bin/bash
exec >> /var/log/install-docker.log 2>&1
set -x

echo "===== start install-docker $(date -Is) ====="

export DEBIAN_FRONTEND=noninteractive

ok=0
for i in $(seq 1 30); do
  if apt-get update -y; then
    ok=1
    break
  fi
  echo "apt-get update tentativa $i falhou"
  sleep 3
done

ok=0
for i in $(seq 1 30); do
  if apt-get install -y docker.io docker-compose jq; then
    ok=1
    break
  fi
  echo "apt-get install docker.io docker-compose tentativa $i falhou"
  sleep 3
done

if [ -x /usr/bin/docker.io ] && [ ! -x /usr/bin/docker ]; then
  ln -sf /usr/bin/docker.io /usr/bin/docker
fi

usermod -aG docker ubuntu || true
systemctl enable docker || true
systemctl start docker || true

for i in $(seq 1 30); do
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "docker ok na tentativa $i"
    break
  fi
  echo "docker ainda nao respondeu na tentativa $i"
  sleep 1
done

set -a
. /usr/local/bin/app-compose-env.sh
set +a

if [ "$USE_ECR" = "true" ]; then
  apt-get install -y awscli
  for i in $(seq 1 30); do
    if aws sts get-caller-identity >/dev/null 2>&1; then
      break
    fi
    echo "esperando credencial IAM tentativa $i"
    sleep 2
  done
  REG_HOST="$(echo "$REGISTRY" | awk -F/ '{print $1}')"
  aws ecr get-login-password | docker login --username AWS --password-stdin "$REG_HOST" || true
else
  if [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
    docker login -u "$REGISTRY_USERNAME" -p "$REGISTRY_PASSWORD" "$REGISTRY" || true
  fi
fi

cd /opt/app
/usr/bin/docker-compose -f /opt/app/docker-compose.yml pull || true
/usr/bin/docker-compose -f /opt/app/docker-compose.yml up -d || true

echo "===== end install-docker $(date -Is) ====="
EOS
chmod 0755 /usr/local/bin/install-docker.sh

cat >/etc/systemd/system/docker-install.service <<EOF
[Unit]
Description=Install Docker and run compose
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/install-docker.sh
TimeoutStartSec=0
RemainAfterExit=yes
StandardOutput=append:/var/log/install-docker.log
StandardError=append:/var/log/install-docker.log

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/app-compose.service <<EOF
[Unit]
Description=Docker Compose App ${APP_NAME}
After=docker-install.service
Requires=docker-install.service

[Service]
Type=simple
WorkingDirectory=/opt/app
ExecStart=/usr/bin/docker-compose -f /opt/app/docker-compose.yml up
ExecStop=/usr/bin/docker-compose -f /opt/app/docker-compose.yml down
Restart=always
RestartSec=5
StandardOutput=append:/var/log/app-compose.log
StandardError=append:/var/log/app-compose.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker-install.service
systemctl enable app-compose.service
systemctl start docker-install.service
systemctl start app-compose.service || true

echo "===== end user-data $(date -Is) ====="
