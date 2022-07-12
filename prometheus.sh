#!/bin/bash

## Load All Function
source utils.sh

## Only Running if Access by root or sudoer user
onlyAllowRoot

## Install Program Apache Utils
sudo apt install apache2-utils -y

## Check if Prometheus Group Exists
groupSystemExist prometheus

## Check if Prometheus User Exists
userSystemExists prometheus prometheus

## Check if Prometheus Directory Exists
directoryCheck /etc/prometheus
directoryCheck /etc/prometheus/rules
directoryCheck /etc/prometheus/rules.d
directoryCheck /etc/prometheus/files_sd
directoryCheck /var/lib/prometheus

## Update Permission
sudo chown -R prometheus:prometheus /var/lib/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chmod -R 775 /etc/prometheus

## Download Prometheus
echo "[INFO] Downloading Prometheus"

directoryCheck /tmp/prometheus
cd /tmp/prometheus
githubDownload prometheus/prometheus latest linux-amd64
tar xvf prometheus*.tar.gz
cd prometheus*/
sudo cp -r prometheus /usr/local/bin/
sudo cp -r promtool /usr/local/bin/
sudo chown -R prometheus:prometheus /usr/local/bin/prometheus
sudo chown -R prometheus:prometheus /usr/local/bin/promtool

## Version Check
echo "[INFO] Checking Prometheus Version"
prometheus --version

echo "[INFO] Checking Promtool Version"
promtool --version

## Create Prometheus Configuration File
echo "[INFO] Creating Prometheus Configuration File"
sudo cp -r prometheus.yml /etc/prometheus/
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /etc/prometheus/prometheus.yml

## Create Password for Prometheus
PROMETHEUS_USERNAME="prometheus"
PROMETHEUS_PASSWORD=$( tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 )
PROMETHEUS_BASIC_AUTH=$( htpasswd -nbBC 10 "$PROMETHEUS_USERNAME" "$PROMETHEUS_PASSWORD" )
PROMETHEUS_PASSWORD_HASH=$( echo $PROMETHEUS_BASIC_AUTH | cut -d':' -f2 )

sudo tee -a /etc/prometheus/auth.txt << EOF
Username: $PROMETHEUS_USERNAME
Password: $PROMETHEUS_PASSWORD
EOF

echo "[INFO] Creating Prometheus Authentication User"
sudo tee -a /etc/prometheus/web.yml<<EOF
basic_auth_users:
    $PROMETHEUS_USERNAME: $PROMETHEUS_PASSWORD_HASH
EOF

echo "[INFO] Verifying Prometheus Authentication User"
promtool check web-config /etc/prometheus/web.yml

## Update Prometheus Configuration File
echo "[INFO] Updating Prometheus Configuration File"
sudo tee -a /etc/prometheus/prometheus.yml<<EOF
    basic_auth:
      username: "$PROMETHEUS_USERNAME"
      password: "$PROMETHEUS_PASSWORD"
EOF

## Create Prometheus Service
echo "[INFO] Creating Prometheus Service"

sudo tee /etc/systemd/system/prometheus.service<<EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.config.file=/etc/prometheus/web.yml \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9090 \\
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

## Update Daemon
echo "[INFO] Updating Prometheus Daemon"
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

## Finished
echo "[INFO] Prometheus Installation Finished"

## Install Node Exporter
echo "[INFO] Installing Node Exporter"
echo "[INFO] Downloading Node Exporter"

directoryCheck /tmp/prometheus
cd /tmp/prometheus
githubDownload prometheus/node_exporter latest linux-amd64
tar xvf node_exporter*.tar.gz
cd node_exporter*/
sudo cp -r node_exporter /usr/local/bin/
sudo chown -R prometheus:prometheus /usr/local/bin/node_exporter

## Version Check
node_exporter --version

## Create Node Exporter Service
echo "[INFO] Creating Node Exporter Service"

sudo tee /etc/systemd/system/node_exporter.service<<EOF
[Unit]
Description=Node Exporter
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/node_exporter \\
    --collector.cpu \\
    --collector.diskstats \\
    --collector.filesystem \\
    --collector.loadavg \\
    --collector.meminfo \\
    --collector.filefd \\
    --collector.netdev \\
    --collector.stat \\
    --collector.netstat \\
    --collector.systemd \\
    --collector.uname \\
    --collector.vmstat \\
    --collector.time \\
    --collector.mdadm \\
    --collector.zfs \\
    --collector.tcpstat \\
    --collector.bonding \\
    --collector.hwmon \\
    --collector.arp \\
    --web.listen-address=0.0.0.0:9100 \\
    --web.telemetry-path="/metrics"

[Install]
WantedBy=multi-user.target
EOF

## Update Daemon
echo "[INFO] Updating Node Exporter Daemon"
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

## Update Prometheus Configuration File
echo "[INFO] Updating Prometheus Configuration File"
sudo tee -a /etc/prometheus/prometheus.yml<<EOF
  - job_name: 'node_exporter_metrics'
    scrape_interval: 5s
    static_configs:
      - targets: ["localhost:9100"]
EOF

## Restart Prometheus
echo "[INFO] Restarting Prometheus"
sudo systemctl restart prometheus

## Finished
echo "[INFO] Node Exporter Installation Finished"
echo "[INFO] Prometheus is now running on http://localhost:9090"
echo "[INFO] Node Exporter is now running on http://localhost:9100"