#!/bin/bash
# Copyright (c) Swarm Library Maintainers.
# SPDX-License-Identifier: MIT

set -e

PROMTAIL_CONFIG_FILE="/etc/promtail/promtail-config.yaml"

# -- The log level of the Promtail server
PROMTAIL_LOGLEVEL=${PROMTAIL_LOGLEVEL:-"info"}

# -- The log format of the Promtail server
# Valid formats: `logfmt, json`
PROMTAIL_LOGFORMAT=${PROMTAIL_LOGFORMAT:-"logfmt"}

# The config of clients of the Promtail server
# -- Loki server configuration
GF_LOKI_SCHEME=${GF_LOKI_SCHEME:-"http"}
GF_LOKI_HOST=${GF_LOKI_HOST:-"loki-gateway"}
GF_LOKI_PORT=${GF_LOKI_PORT:-"80"}
GF_LOKI_ADDR=${GF_LOKI_ADDR:-"${GF_LOKI_SCHEME}://${GF_LOKI_HOST}:${GF_LOKI_PORT}"}
GF_LOKI_URL=${GF_LOKI_URL:-"${GF_LOKI_ADDR}/loki/api/v1/push"}
PROMTAIL_CLIENT_URL=${PROMTAIL_CLIENT_URL:-$GF_LOKI_URL}

# -- Configures where Promtail will save it's positions file, to resume reading after restarts.
PROMTAIL_POSITION_FILENAME=${PROMTAIL_POSITION_FILENAME:-"/promtail/positions.yaml"}

# -- The config to enable tracing
PROMTAIL_ENABLE_TRACING=${PROMTAIL_ENABLE_TRACING:-"false"}

# -- Config file contents for Promtail.
cat <<EOF >${PROMTAIL_CONFIG_FILE}
server:
  log_level: ${PROMTAIL_LOGLEVEL}
  log_format: ${PROMTAIL_LOGFORMAT}
  http_listen_port: 9080

clients:
  - url: ${PROMTAIL_CLIENT_URL}

positions:
  filename: ${PROMTAIL_POSITION_FILENAME}

tracing:
      enabled: ${PROMTAIL_ENABLE_TRACING}
EOF

cat <<EOF >>${PROMTAIL_CONFIG_FILE}
scrape_configs:
  - job_name: docker

    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 10s

    pipeline_stages:
      - docker: {}

    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'

      # ================================================================================
      # Label mapping
      # ================================================================================
      - action: labelmap
        regex: __meta_docker_container_label_com_(docker_.*)

      # Rename labels docker_swarm_(.+) to dockerswarm_\$1
      # This is useful for compatibility with "dockerswarm-tasks.yml" relabeling
      - action: labelmap
        regex: __meta_docker_container_label_com_docker_swarm_(.+)
        replacement: dockerswarm_\$1
      - action: labeldrop
        regex: (^docker_swarm_.+)

      # ================================================================================
      # Docker Swarm compatible relabeling
      # - dockerswarm_task_name
      # ================================================================================

      # Set "task" label to "<service_name>.<task_slot>
      - source_labels:
        - dockerswarm_task_name
        target_label: task
        regex: (.+)\.(.+)\.(.+)
        replacement: \$1.\$2

      # ================================================================================
      # Kubernetes compatible relabeling
      # - namespace
      # - deployment
      # - pod
      # ================================================================================
      # # Set Kubernetes's Namespace with "com.docker.stack.namespace" label
      - source_labels:
        - __meta_docker_container_label_com_docker_stack_namespace
        target_label: namespace

      # Set Kubernetes's Deployment with "com.docker.stack.namespace" label
      - source_labels:
        - __meta_docker_container_label_com_docker_swarm_service_name
        target_label: deployment

      # Set Kubernetes's Pod Name with Docker Swarm's Service Name
      - source_labels:
        - dockerswarm_task_name
        target_label: pod
        regex: (.*)
EOF

# If the user is trying to run Prometheus directly with some arguments, then
# pass them to Prometheus.
if [ "${1:0:1}" = '-' ]; then
    set -- promtail "$@"
fi

# If the user is trying to run Prometheus directly with out any arguments, then
# pass the configuration file as the first argument.
if [ "$1" = "" ]; then
    set -- promtail \
      -config.expand-env=true \
      -config.file=${PROMTAIL_CONFIG_FILE} \
      -server.enable-runtime-reload
fi

echo "==> Starting Promtail..."
set -x
exec "$@"
