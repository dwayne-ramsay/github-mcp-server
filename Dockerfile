# ─────────────────────────────────────────────
# Stage 1: Build the Go binary
# go.mod requires go >= 1.25; use 1.26-alpine (latest stable)
# ─────────────────────────────────────────────
FROM golang:1.26-alpine AS builder

# git is required by some Go module dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Cache dependency layer separately
COPY go.mod go.sum ./
RUN go mod download

# Copy full source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o github-mcp-server ./cmd/github-mcp-server

# ─────────────────────────────────────────────
# Stage 2: Runtime — Node + Supergateway wrapper
# ─────────────────────────────────────────────
FROM node:20-alpine

# Install supergateway globally
RUN npm install -g supergateway

# Copy compiled binary from builder
COPY --from=builder /app/github-mcp-server /usr/local/bin/github-mcp-server
RUN chmod +x /usr/local/bin/github-mcp-server

# Railway injects PORT automatically; default to 8000
ENV PORT=8000
EXPOSE 8000

# Start: wrap the stdio MCP server with Supergateway over Streamable HTTP
CMD ["sh", "-c", \
  "supergateway \
    --stdio 'github-mcp-server stdio' \
    --port ${PORT} \
    --outputTransport streamableHttp \
    --streamableHttpPath /mcp"]
