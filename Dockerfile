FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y make openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app

