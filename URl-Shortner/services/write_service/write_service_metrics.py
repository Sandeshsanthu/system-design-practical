from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from flask import Response

# Request metrics
REQUEST_COUNT = Counter(
    'write_service_requests_total',
    'Total requests to write service',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'write_service_request_duration_seconds',
    'Request latency in seconds',
    ['method', 'endpoint'],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0)
)

# Database metrics
DB_QUERY_DURATION = Histogram(
    'write_service_db_query_duration_seconds',
    'Database query duration in seconds',
    ['query_type', 'database'],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
)

DB_QUERY_COUNT = Counter(
    'write_service_db_queries_total',
    'Total database queries',
    ['query_type', 'database', 'status']
)

DB_CONNECTION_POOL = Gauge(
    'write_service_db_connection_pool_size',
    'Current database connection pool size',
    ['database', 'state']
)

# Redis metrics
REDIS_OPERATION_DURATION = Histogram(
    'write_service_redis_operation_duration_seconds',
    'Redis operation duration in seconds',
    ['operation'],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5)
)

REDIS_OPERATION_COUNT = Counter(
    'write_service_redis_operations_total',
    'Total Redis operations',
    ['operation', 'status']
)

# Business metrics
URL_CREATED = Counter(
    'write_service_urls_created_total',
    'Total URLs created'
)

URL_CREATION_ERRORS = Counter(
    'write_service_url_creation_errors_total',
    'Total URL creation errors',
    ['error_type']
)

# RabbitMQ metrics (for future use)
RABBITMQ_PUBLISH_COUNT = Counter(
    'write_service_rabbitmq_published_total',
    'Total messages published to RabbitMQ',
    ['queue']
)

RABBITMQ_PUBLISH_ERRORS = Counter(
    'write_service_rabbitmq_publish_errors_total',
    'Total RabbitMQ publish errors',
    ['queue']
)

# Metrics endpoint function
def metrics_endpoint():
    """Generate Prometheus metrics output"""
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

# Placeholder for decorators (if you want to use them in future)
def track_request_metrics(f):
    return f

def track_db_query(query_type, database='primary'):
    def decorator(f):
        return f
    return decorator

def track_redis_operation(operation):
    def decorator(f):
        return f
    return decorator
