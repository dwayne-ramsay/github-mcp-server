FROM node:20-alpine@sha256:09e2b3d9726018aecf269bd35325f46bf75046a643a66d28360ec71132750ec8 AS ui-build

WORKDIR /app

COPY ui/package*.json ./ui/
RUN cd ui && npm ci

COPY ui/ ./ui/

RUN mkdir -p ./pkg/github/ui_dist && \
    cd ui && npm run build


FROM golang:1.25.9-alpine@sha256:5caaf1cca9dc351e13deafbc3879fd4754801acba8653fa9540cea125d01a71f AS build

ARG VERSION="dev"

WORKDIR /build

RUN apk add --no-cache ca-certificates git

COPY . .

COPY --from=ui-build /app/pkg/github/ui_dist/* ./pkg/github/ui_dist/

RUN CGO_ENABLED=0 go build \
    -ldflags="-s -w -X main.version=${VERSION} -X main.commit=$(git rev-parse HEAD) -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o /bin/github-mcp-server ./cmd/github-mcp-server


FROM python:3.12-alpine

LABEL io.modelcontextprotocol.server.name="io.github.github/github-mcp-server"

WORKDIR /server

RUN apk add --no-cache ca-certificates && \
    pip install --no-cache-dir mcp-proxy

COPY --from=build /bin/github-mcp-server .

EXPOSE 8080

CMD sh -c 'mcp-proxy \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  -- \
  /server/github-mcp-server stdio'
