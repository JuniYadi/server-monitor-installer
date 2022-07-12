#!/bin/bash

## Load All Function
source utils.sh

## Only Running if Access by root or sudoer user
onlyAllowRoot

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

## Create Prometheus Service
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
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

## Create Prometheus Configuration File
echo "[INFO] Creating Prometheus Configuration File"
sudo cp -r prometheus.yml /etc/prometheus/
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /etc/prometheus/prometheus.yml

## Update Daemon
echo "[INFO] Updating Prometheus Daemon"
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

## Finished
echo "[INFO] Prometheus Installation Finished"
echo "[INFO] Prometheus is now running on http://localhost:9090"