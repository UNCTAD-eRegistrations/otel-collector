# OpenTelemetry Observability for eRegistrations

## Overview

The eRegistrations platform is now instrumented with OpenTelemetry (OTel), providing end-to-end distributed tracing, metrics, and alerting across all backend services. This gives the team real-time visibility into how requests flow through the system, where errors occur, and which services degrade performance.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Instrumented Services                         │
│                                                                      │
│  Java (Agent)          Python (SDK)         Node.js (SDK)            │
│  ┌─────────────┐      ┌─────────────┐      ┌──────────────────┐     │
│  │ bpa-backend  │      │ ds-backend   │      │ chrome-url-to-pdf│     │
│  │ camunda      │      │ gdb          │      │ js-assistant     │     │
│  │ mule3        │      │ statistics-  │      │ websocket        │     │
│  │ restheart    │      │   backend    │      │ clamav           │     │
│  │ keycloak     │      └─────────────┘      │ formio           │     │
│  │ dataweave    │                            └──────────────────┘     │
│  │ cashier      │                                                    │
│  └─────────────┘                                                     │
│         │                     │                       │              │
│         └─────────────────────┼───────────────────────┘              │
│                               │ OTLP gRPC (:4317)                    │
└───────────────────────────────┼──────────────────────────────────────┘
                                ▼
                ┌───────────────────────────────┐
                │     OTel Collector (0.144.0)   │
                │                               │
                │  Processors:                  │
                │    filter → resource → batch  │
                │                               │
                │  Connectors:                  │
                │    spanmetrics (:8890)         │
                │    servicegraph (:8891)        │
                └──────┬────────┬───────┬───────┘
                       │        │       │
              ┌────────┘        │       └────────┐
              ▼                 ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ Tempo 2.10.0 │  │Prometheus 3.5│  │Alertmgr 0.31│
    │              │  │              │  │              │
    │  Trace       │  │  Metrics     │  │  Alert       │
    │  Storage     │  │  Storage     │  │  Routing     │
    └──────┬───────┘  └──────┬───────┘  └──────────────┘
           │                 │
           └────────┬────────┘
                    ▼
          ┌──────────────────┐
          │  Grafana 12.3.2  │
          │                  │
          │  11 Dashboards   │
          │  16 Alert Rules  │
          └──────────────────┘
```

### Components

| Component | Version | Role |
|-----------|---------|------|
| **OTel Collector** | 0.144.0 (contrib) | Receives traces via OTLP, filters noise, exports to Tempo/Prometheus |
| **Tempo** | 2.10.0 | Distributed trace storage and search (vParquet4) |
| **Prometheus** | v3.5.1 | Metrics storage, alerting rule evaluation |
| **Alertmanager** | v0.31.0 | Alert routing and notifications |
| **Grafana** | 12.3.2 | Visualization, dashboards, Explore view |

### Instrumented Services (16 total)

| Service | Language | Instrumentation | Role in Platform |
|---------|----------|-----------------|------------------|
| bpa-backend | Java | Agent | Core BPA business logic |
| camunda | Java | Agent | Workflow/process engine |
| mule3 | Java | Agent | Integration/ESB layer |
| restheart | Java | Agent | MongoDB REST API |
| keycloak | Java | Agent | Authentication (SSO/OAuth) |
| dataweave | Java | Agent | Data transformation |
| cashier | Java | Agent | Payment processing |
| ds-backend | Python | SDK | Digital Services backend |
| gdb | Python | SDK | Government Database |
| statistics-backend | Python | SDK | Statistics/reporting |
| chrome-url-to-pdf | Node.js | SDK | PDF generation |
| js-assistant | Node.js | SDK | JavaScript helper service |
| websocket | Node.js | SDK | Real-time notifications |
| clamav | Node.js | SDK | Antivirus scanning |
| formio | Node.js | SDK | Form engine |
| publisher | — | Env vars only | Document publisher |

### Data Pipeline

1. **Collection**: Each service sends traces to the OTel Collector via OTLP gRPC (port 4317)
2. **Filtering**: Health check spans (`/health`, `/status`, `/actuator`) are dropped at the collector using OTTL-based filter rules to avoid noise
3. **Processing**: Resource attributes (environment, platform) are added; spans are batched for efficiency
4. **Derived metrics**: The `spanmetrics` connector generates request rate, error rate, and latency histograms from traces. The `servicegraph` connector builds a service dependency graph
5. **Storage**: Traces go to Tempo, derived metrics go to Prometheus (via separate exporters to avoid namespace collisions)
6. **Alerting**: Prometheus evaluates 16 alerting rules and routes firing alerts through Alertmanager
7. **Visualization**: Grafana reads from both Tempo and Prometheus, with cross-links between metrics and traces

## Dashboards

### 1. SLO/SLI Dashboard
**Purpose**: Track service availability and latency against targets.

Shows per-service availability gauges (target: 99.9%), p95 latency trends, and error rates. Answers: *"Are we meeting our availability targets?"*

### 2. Error Analysis
**Purpose**: Identify and drill into errors across the platform.

Shows error rates by service, error counts, top error-producing operations, and a **Recent Error Traces** table from Tempo. All error panels have **click-through links** that open Grafana Explore with the matching TraceQL query.

### 3. Latency Analysis
**Purpose**: Find performance bottlenecks.

Shows p50/p95/p99 latency percentiles per service, slowest operations, and latency trends over time.

### 4. Authentication Flow Analysis
**Purpose**: Monitor Keycloak authentication performance.

Shows auth success rate, latency, throughput, and top operations. Useful for detecting login issues or SSO degradation.

### 5. Payment Flow Monitoring
**Purpose**: Track payment processing through the cashier service.

Shows payment success rate, latency, volume, and throughput. Health check spans are filtered out so metrics reflect real transactions only.

### 6. PDF Generation Performance
**Purpose**: Monitor chrome-url-to-pdf service.

Shows PDF generation success rate, latency, and throughput for certificate/document generation.

### 7. Root Cause Analysis (RCA)
**Purpose**: Correlate errors across services to find root causes.

Shows total error rate, number of services with errors, top error sources, and error-producing operations.

### 8. Service Dependency Map
**Purpose**: Visualize how services communicate.

Uses the servicegraph connector to show a node graph of service-to-service calls with error rates overlaid.

### 9. Alerts Overview
**Purpose**: Monitor active alerts.

Shows firing and pending alerts, alert timeline, and breakdown by service/severity.

### 10. eRegistrations Traces
**Purpose**: Explore trace data and service operations.

Shows top operations by rate, slow operations (p95 > 200ms), error operations, and a Tempo service map.

### 11. OpenTelemetry Traces
**Purpose**: Raw trace search via Tempo.

Direct access to TraceQL search for ad-hoc trace investigation.

## Alerting Rules (16)

| Alert | Severity | Condition |
|-------|----------|-----------|
| HighErrorRate | warning | Error rate > 5% for 5m |
| CriticalErrorRate | critical | Error rate > 10% for 2m |
| HighLatency | warning | p99 latency > 5000ms for 5m |
| ServiceDown | critical | No spans from a service for 5m (was active before) |
| ErrorRateSpike | warning | Error rate doubled vs. 1h average |
| PDFGenerationSlow | warning | PDF p95 > 60000ms for 5m |
| PaymentProcessingErrors | critical | Payment error rate > 1% |
| DatabaseConnectionFailure | critical | DB operation error rate > 50% for 2m |
| CamundaEngineFailure | critical | Camunda error rate > 10% for 5m |
| BotRoleFailures | warning | BOT role error rate > 5% for 10m |
| DSBackendLatencySLOBreach | warning | DS-Backend p99 > 2000ms for 5m |
| FormLoadTimeSlow | warning | Formio p95 > 500ms for 5m |
| PaymentProcessingSlow | warning | Cashier p95 > 30000ms for 3m |
| AuthenticationFailuresSpike | warning | Keycloak > 10 errors/s for 5m |
| ExternalServiceTimeouts | warning | Mule3 error rate > 10% for 5m |
| FormioSubmissionErrors | warning | Formio > 1 error/s for 5m |

## Answering Questions with OTel

### "Why is the application slow right now?"

1. Open **Latency Analysis** dashboard (`/d/ereg-latency-analysis`)
2. Check the **p95 Latency by Service** panel — identify which service has elevated latency
3. Look at **Slowest Operations** to find the specific endpoint
4. Click the operation bar → opens **Explore** with the matching traces
5. In Explore, click a trace → view the **span waterfall** to see where time is spent (DB query? External call? Processing?)

### "A user reported an error during registration. What happened?"

1. Open **Error Analysis** dashboard (`/d/ereg-error-analysis`)
2. Check **Error Operations (by rate)** — find the endpoint that matches the user's action
3. Click the bar → opens Explore with error traces for that operation
4. In the trace waterfall, look for the red error span — it shows the **exception type and message**
5. Expand the span attributes for HTTP status code, URL path, and error details
6. Check if the trace spans multiple services (e.g., ds-backend → restheart → MongoDB) to see if the error originated upstream

### "Is the payment system working?"

1. Open **Payment Flow** dashboard (`/d/ereg-payment-flow`)
2. Check **Payment Success Rate** — should be close to 100%
3. Check **Payment Volume** — if zero, no payments were processed in the time window
4. Check **Payment Latency (p95)** — if above 5s, the cashier service may be degraded
5. If errors exist, check **Cashier Operations** to find the failing endpoint

### "Did the last deployment break anything?"

1. Open **SLO/SLI Dashboard** (`/d/ereg-slo-dashboard`)
2. Check all **Availability** gauges — any drop below 99.9% indicates a problem
3. Open **Error Analysis** and narrow the time range to the deployment window
4. Compare **Error Rate Over Time** before and after the deployment
5. Check **Alerts Overview** (`/d/ereg-alerts`) for any alerts that fired during/after deployment

### "Which services depend on each other?"

1. Open **Service Dependency Map** (`/d/ereg-service-map`)
2. The **node graph** shows directed edges between services (client → server)
3. Edge thickness indicates request volume; red edges indicate error rates
4. For a specific service, use **eRegistrations Traces** → service map for detailed topology

### "Authentication is failing for some users. What's wrong?"

1. Open **Auth Flow** dashboard (`/d/ereg-auth-flow`)
2. Check **Auth Success Rate** and **Error Rate** gauges
3. If error rate is elevated, check **Keycloak Operations** to find the failing endpoint (e.g., `/realms/{realm}/protocol/{protocol}/token`)
4. Open **Explore** → Tempo → run TraceQL: `{resource.service.name="keycloak" && status=error}`
5. Inspect the error trace for exception details (expired token, invalid credentials, realm misconfiguration)

### "How do I find a specific trace?"

1. Open **Explore** (compass icon in Grafana sidebar)
2. Select **Tempo** datasource
3. Choose **Search** tab
4. Set filters: Service Name, Status (error/ok), min/max Duration, Span Name
5. Click **Run query** — results show matching traces
6. Click a trace ID to see the full waterfall
7. Alternative: if you have a trace ID, switch to **TraceQL** tab and run: `{traceID="abc123..."}`

### "How many requests is each service handling?"

1. Open **eRegistrations Traces** dashboard (`/d/ereg-traces`)
2. Check **Top Operations (by rate)** — shows request rate per service and operation
3. For a specific service, use Prometheus query in Explore: `sum by (span_name) (rate(traces_spanmetrics_calls_total{service_name="ds-backend"}[5m]))`

## Deployments

The OTel stack is deployed on two environments:

| Environment | Grafana URL | Collector Config |
|-------------|-------------|------------------|
| dev.cuba | `https://grafana.dev.cuba.eregistrations.org` | `/home/jenkins/eregistrations/Conf-DEV/compose/cuba/otel-collector/` |
| bridge (govbridge.org) | `https://grafana.govbridge.org` | `/opt/govbridge-dev/repos/otel-collector/` |

Both are managed from the same Git repository: [UNCTAD-eRegistrations/otel-collector](https://github.com/UNCTAD-eRegistrations/otel-collector)

### Restarting Services

```bash
# Restart entire OTel stack
docker compose restart

# Restart only the collector (after config changes)
docker restart otel-collector

# Restart Grafana (after dashboard JSON changes)
docker restart grafana-otel
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `otel-collector-config.yaml` | Collector pipelines, filters, connectors, exporters |
| `docker-compose.yml` | Service definitions, ports, volumes |
| `.env` | Deployment-specific variables (e.g., `GRAFANA_ROOT_URL`) |
| `prometheus/prometheus.yml` | Scrape targets and alerting rule files |
| `prometheus/alerting-rules.yml` | Prometheus alerting rule definitions |
| `grafana/provisioning/datasources/datasources.yml` | Tempo + Prometheus datasource config |
| `grafana/provisioning/dashboards/*.json` | All 11 dashboard definitions |
