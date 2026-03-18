GH_OWNER="fatedier" \
REPO="frp" \
ASSET_PREFIX="frp" \
BINARY_NAME="frps" \
CONFIG_FILE="frps.toml" \
IMAGE_NAME="frp" \
GH_USER="julaw-energy" \
TAG="latest" && \
cat <<'EOF' > /tmp/Dockerfile
FROM alpine:latest AS download

ARG TARGETARCH
ARG GH_OWNER
ARG REPO
ARG ASSET_PREFIX
ARG BINARY_NAME
ARG CONFIG_FILE

RUN echo "=== BUILD ARGS RECEIVED ===" && \
    echo "GH_OWNER     = ${GH_OWNER:-NOT_SET}" && \
    echo "REPO         = ${REPO:-NOT_SET}" && \
    echo "ASSET_PREFIX = ${ASSET_PREFIX:-NOT_SET}" && \
    echo "BINARY_NAME  = ${BINARY_NAME:-NOT_SET}" && \
    echo "CONFIG_FILE  = ${CONFIG_FILE:-NOT_SET}" && \
    echo "TARGETARCH   = ${TARGETARCH:-NOT_SET}" && \
    echo "============================="

RUN apk add --no-cache curl jq

RUN VERSION=$(curl -s https://api.github.com/repos/${GH_OWNER}/${REPO}/releases/latest | jq -r .tag_name) && \
    ASSET_NAME="${ASSET_PREFIX}_${VERSION#v}_linux_${TARGETARCH}.tar.gz" && \
    echo "Downloading ${ASSET_NAME} for ${TARGETARCH}" && \
    curl -L -o /tmp/app.tar.gz https://github.com/${GH_OWNER}/${REPO}/releases/download/${VERSION}/${ASSET_NAME} && \
    mkdir -p /tmp/extract /app && \
    tar -xzf /tmp/app.tar.gz -C /tmp/extract --strip-components=1 && \
    cp /tmp/extract/${BINARY_NAME} /app/ && \
    cp /tmp/extract/LICENSE /app/ 2>/dev/null || true && \
    cp /tmp/extract/${CONFIG_FILE} /app/ 2>/dev/null || true && \
    ls -lh /app

FROM busybox:1.37.0-musl

COPY --from=download /app /app

WORKDIR /app
RUN chmod +x /app/${BINARY_NAME}

# Files are now in /app (binary + LICENSE + config file)
# Uncomment the next line if you want the container to run the binary by default:
ENTRYPOINT ["/app/${BINARY_NAME}", "-c", "/app/${CONFIG_FILE}"]
EOF

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg GH_OWNER=${GH_OWNER} \
  --build-arg REPO=${REPO} \
  --build-arg ASSET_PREFIX=${ASSET_PREFIX} \
  --build-arg BINARY_NAME=${BINARY_NAME} \
  --build-arg CONFIG_FILE=${CONFIG_FILE} \
  -f /tmp/Dockerfile \
  --push -t ghcr.io/${GH_USER}/${IMAGE_NAME}:${TAG} .