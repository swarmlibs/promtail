ARG PROMTAIL_VERSION=latest
FROM grafana/promtail:${PROMTAIL_VERSION}
ADD rootfs /
ENTRYPOINT [ "/docker-entrypoint.sh" ]
VOLUME [ "/promtail" ]
