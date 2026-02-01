# OpenTelemetry Collector

Foundation service for distributed tracing across the eRegistrations stack.

## Components

- **OTel Collector**: Receives traces via OTLP (gRPC/HTTP) and forwards to Tempo
- **Tempo**: Trace storage and query backend
- **Grafana**: Visualization UI with Tempo datasource

## Usage

### Start the stack
```bash
docker-compose up -d
```

### Access Grafana
http://localhost:3000

### Send test trace
```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": { "stringValue": "test-service" }
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "'$(openssl rand -hex 16)'",
          "spanId": "'$(openssl rand -hex 8)'",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "'$(date +%s)000000000'",
          "endTimeUnixNano": "'$(date +%s)000000000'"
        }]
      }]
    }]
  }'
```

### Query traces
```bash
# Via Tempo API
curl http://localhost:3200/api/search?service=test-service

# Via Grafana
# Open http://localhost:3000 and use the "Explore" feature
```

## Configuration

- `otel-collector-config.yaml`: Collector receivers, processors, exporters
- `tempo.yaml`: Tempo storage and ingestion settings
- `grafana/provisioning/`: Automatic datasource and dashboard setup

## Endpoints

| Service | Endpoint | Port | Description |
|---------|----------|------|-------------|
| Collector gRPC | otel-collector:4317 | 4317 | OTLP gRPC traces |
| Collector HTTP | otel-collector:4318 | 4318 | OTLP HTTP traces |
| Collector Metrics | otel-collector:8889 | 8889 | Prometheus metrics |
| Tempo Query | tempo:3200 | 3200 | Trace search/query |
| Grafana | localhost:3000 | 3000 | Web UI |

## Deployment

This service is part of the eRegistrations dev stack. Ensure it's running before starting other services with OTel instrumentation.
