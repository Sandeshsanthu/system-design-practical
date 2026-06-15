# filename: redirect_service_metrics.py
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from flask import Response, request
import time
from functools import wraps

# Request metrics
REQUEST_COUNT = Counter(
    'redirect_service_requests_total',
    'Total requests to redirect service',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'redirect_service_request_duration_seconds',
    'Request latency in seconds',
    ['method', 'endpoint'],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0)
)

# Database metrics (Reads from Replica Router)
DB_QUERY_DURATION = Histogram(
    'redirect_service_db_query_duration_seconds',
    'Database query duration in seconds',
    ['query_type', 'database'],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
)

DB_QUERY_COUNT = Counter(
    'redirect_service_db_queries_total',
    'Total database queries',
    ['query_type', 'database', 'status']
)

DB_CONNECTION_POOL = Gauge(
    'redirect_service_db_connection_pool_size',
    'Current database connection pool size',
    ['database', 'state']
)

# Redis Cache layer metrics
REDIS_OPERATION_DURATION = Histogram(
    'redirect_service_redis_operation_duration_seconds',
    'Redis operation duration in seconds',
    ['operation'],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5)
)

REDIS_OPERATION_COUNT = Counter(
    'redirect_service_redis_operations_total',
    'Total Redis operations',
    ['operation', 'status']
)

# Core Business and Analytics metrics
REDIRECTS_TOTAL = Counter(
    'redirect_service_redirects_total',
    'Total short link redirection executions',
    ['short_code']
)

CACHE_HIT_COUNT = Counter(
    'redirect_service_cache_hits_total',
    'Total cache evaluations tracking hit/miss status',
    ['status']  # 'hit' or 'miss'
)

REDIRECT_ERRORS = Counter(
    'redirect_service_errors_total',
    'Total redirect failure exceptions',
    ['error_type']  # 'expired', 'not_found', 'db_error'
)


# Decorator for tracking incoming request metrics
def track_request_metrics(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        start_time = time.time()
        method = request.method
        endpoint = request.endpoint or 'unknown'

        try:
            response = f(*args, **kwargs)
            status = response.status_code if hasattr(response, 'status_code') else 200
            REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status).inc()
            return response
        except Exception as e:
            REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=500).inc()
            raise
        finally:
            REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)

    return decorated_function


# Decorator for tracking database read queries
def track_db_query(query_type, database='replica'):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            try:
                result = f(*args, **kwargs)
                DB_QUERY_COUNT.labels(query_type=query_type, database=database, status='success').inc()
                return result
            except Exception as e:
                DB_QUERY_COUNT.labels(query_type=query_type, database=database, status='error').inc()
                raise
            finally:
                DB_QUERY_DURATION.labels(query_type=query_type, database=database).observe(time.time() - start_time)

        return wrapper

    return decorator


# Decorator for tracking Redis operations
def track_redis_operation(operation):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            try:
                result = f(*args, **kwargs)
                REDIS_OPERATION_COUNT.labels(operation=operation, status='success').inc()
                return result
            except Exception as e:
                REDIS_OPERATION_COUNT.labels(operation=operation, status='error').inc()
                raise
            finally:
                REDIS_OPERATION_DURATION.labels(operation=operation).observe(time.time() - start_time)

        return wrapper

    return decorator


# Flask endpoint for metrics
def metrics_endpoint():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
