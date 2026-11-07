# syntax=docker/dockerfile:1
# fivem-enhanced: a launcher image for the Cfx.re FXServer (GTA V Enhanced).
#
# The server artifact is not in this image. entrypoint.sh downloads the build
# named by CFX_URL into the /opt/cfx volume on first start, so one image tag
# serves every server build and nothing of Cfx.re's is redistributed.
FROM alpine:3.22

RUN apk add --no-cache ca-certificates curl xz

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# /opt/cfx holds the fetched artifact; /txData is txAdmin's data directory.
VOLUME ["/opt/cfx", "/txData"]
WORKDIR /txData
EXPOSE 30120/tcp 30120/udp 40120/tcp

LABEL org.opencontainers.image.source="https://github.com/chaosen3/fivem-enhanced-docker" \
      org.opencontainers.image.description="FXServer launcher for FiveM (GTA V Enhanced); fetches the Cfx.re artifact at first start" \
      org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
