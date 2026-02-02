# Build stage - use official collector contrib image as base
FROM otel/opentelemetry-collector-contrib:0.95.0

# Copy the custom configuration into the image
COPY otel-collector-config.yaml /etc/otel/config.yaml

# Expose the standard OTel Collector ports
EXPOSE 4317 4318 8888 8889 13133

# Use the config baked into the image
ENTRYPOINT ["/otelcol-contrib"]
CMD ["--config=/etc/otel/config.yaml"]
