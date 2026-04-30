# Stage 1: Build the Go binary
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o github-mcp-server ./cmd/github-mcp-server

# Stage 2: Runtime with Supergateway
FROM node:20-alpine
RUN npm install -g supergateway

# Copy the Go binary
COPY --from=builder /app/github-mcp-server /usr/local/bin/github-mcp-server
RUN chmod +x /usr/local/bin/github-mcp-server

ENV PORT=8000
EXPOSE 8000

CMD ["sh", "-c", "supergateway \
  --stdio 'github-mcp-server stdio' \
  --port ${PORT} \
  --outputTransport streamableHttp \
  --streamableHttpPath /mcp"]
