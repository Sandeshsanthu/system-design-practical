from flask import Flask, request, jsonify, make_response
import psycopg2
import redis
from datetime import datetime, timedelta
from url_encoder import Base62Encoder
from rate_limiter import RateLimiter
import sys
from flask_cors import CORS
import time

sys.path.append('../..')
from config import Config

from write_service_metrics import (
    track_request_metrics, track_db_query, track_redis_operation,
    URL_CREATED, URL_CREATION_ERRORS, RABBITMQ_PUBLISH_COUNT,
    RABBITMQ_PUBLISH_ERRORS, DB_CONNECTION_POOL, metrics_endpoint,
    REQUEST_COUNT, REQUEST_LATENCY, DB_QUERY_DURATION, DB_QUERY_COUNT,
    REDIS_OPERATION_DURATION, REDIS_OPERATION_COUNT
)

# Create the app instance ONCE and apply CORS right away
app = Flask(__name__)
CORS(app)

encoder = Base62Encoder()

# Redis for rate limiting and caching
redis_client = redis.Redis(
    host=Config.REDIS_HOST,
    port=Config.REDIS_PORT,
    decode_responses=True
)

rate_limiter = RateLimiter(redis_client)

# Database connection pool tracking
db_connection_pool = {'active': 0, 'idle': 0}


# Connect to PostgreSQL Primary (for writes)
def get_db_connection():
    """Get database connection with connection pool metrics"""
    db_connection_pool['active'] += 1
    DB_CONNECTION_POOL.labels(database='primary', state='active').set(db_connection_pool['active'])

    try:
        conn = psycopg2.connect(
            host=Config.DB_PRIMARY_HOST,
            port=Config.DB_PRIMARY_PORT,
            database=Config.DB_NAME,
            user=Config.DB_USER,
            password=Config.DB_PASSWORD
        )
        return conn
    except Exception as e:
        db_connection_pool['active'] -= 1
        DB_CONNECTION_POOL.labels(database='primary', state='active').set(db_connection_pool['active'])
        raise


def close_db_connection(conn):
    """Close database connection and update metrics"""
    if conn:
        conn.close()
        db_connection_pool['active'] -= 1
        DB_CONNECTION_POOL.labels(database='primary', state='active').set(db_connection_pool['active'])


# Redis operations with metrics
def redis_get(key):
    """Redis GET with metrics tracking"""
    start_time = time.time()
    try:
        result = redis_client.get(key)
        REDIS_OPERATION_COUNT.labels(operation='get', status='success').inc()
        return result
    except Exception as e:
        REDIS_OPERATION_COUNT.labels(operation='get', status='error').inc()
        raise
    finally:
        REDIS_OPERATION_DURATION.labels(operation='get').observe(time.time() - start_time)


def redis_setex(key, ttl, value):
    """Redis SETEX with metrics tracking"""
    start_time = time.time()
    try:
        result = redis_client.setex(key, ttl, value)
        REDIS_OPERATION_COUNT.labels(operation='set', status='success').inc()
        return result
    except Exception as e:
        REDIS_OPERATION_COUNT.labels(operation='set', status='error').inc()
        raise
    finally:
        REDIS_OPERATION_DURATION.labels(operation='set').observe(time.time() - start_time)


def redis_ping():
    """Redis PING with metrics tracking"""
    start_time = time.time()
    try:
        result = redis_client.ping()
        REDIS_OPERATION_COUNT.labels(operation='ping', status='success').inc()
        return result
    except Exception as e:
        REDIS_OPERATION_COUNT.labels(operation='ping', status='error').inc()
        raise
    finally:
        REDIS_OPERATION_DURATION.labels(operation='ping').observe(time.time() - start_time)


# Database queries with metrics
def db_execute_query(cursor, query, params, query_type='select'):
    """Execute database query with metrics tracking"""
    start_time = time.time()
    try:
        cursor.execute(query, params)
        DB_QUERY_COUNT.labels(query_type=query_type, database='primary', status='success').inc()
        return cursor
    except Exception as e:
        DB_QUERY_COUNT.labels(query_type=query_type, database='primary', status='error').inc()
        raise
    finally:
        DB_QUERY_DURATION.labels(query_type=query_type, database='primary').observe(time.time() - start_time)


# Metrics endpoint
@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return metrics_endpoint()


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for Docker"""
    start_time = time.time()
    endpoint = 'health_check'
    method = 'GET'

    try:
        # Check database connection
        conn = get_db_connection()
        cursor = conn.cursor()
        db_execute_query(cursor, "SELECT 1", None, 'health_check')
        cursor.close()
        close_db_connection(conn)

        # Check Redis connection
        redis_ping()

        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='200').inc()
        response = jsonify({
            'status': 'healthy',
            'services': 'write-service',
            'database': 'connected',
            'redis': 'connected'
        }), 200

        return response

    except Exception as e:
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='503').inc()
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 503
    finally:
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)


@app.route('/shorten', methods=['POST', 'OPTIONS'])
def shorten_url():
    """Create shortened URL with full metrics tracking"""
    start_time = time.time()
    endpoint = 'shorten_url'
    method = request.method

    # Handle preflight OPTIONS request
    if request.method == 'OPTIONS':
        response = make_response()
        response.headers.add("Access-Control-Allow-Origin", "*")
        response.headers.add("Access-Control-Allow-Headers", "Content-Type, Authorization")
        response.headers.add("Access-Control-Allow-Methods", "POST, OPTIONS")
        REQUEST_COUNT.labels(method='OPTIONS', endpoint=endpoint, status='200').inc()
        REQUEST_LATENCY.labels(method='OPTIONS', endpoint=endpoint).observe(time.time() - start_time)
        return response, 200

    # Rate limiting check
    client_ip = request.remote_addr
    if not rate_limiter.allow_request(client_ip):
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='429').inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)
        URL_CREATION_ERRORS.labels(error_type='RateLimitExceeded').inc()
        return jsonify({'error': 'Rate limit exceeded'}), 429

    data = request.json or {}
    original_url = data.get('url')
    created_by = data.get('created_by', 'anonymous')
    expires_in_days = data.get('expires_in_days')

    if not original_url:
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='400').inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)
        URL_CREATION_ERRORS.labels(error_type='MissingURL').inc()
        return jsonify({'error': 'URL is required'}), 400

    # Calculate expiration
    expiration_time = None
    if expires_in_days:
        expiration_time = datetime.now() + timedelta(days=expires_in_days)

    cursor = None
    conn = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Insert URL and get auto-generated ID
        db_execute_query(
            cursor,
            """
            INSERT INTO urls (url, short_url, created_by, expiration_time, status)
            VALUES (%s, %s, %s, %s, 'active')
            RETURNING id
            """,
            (original_url, 'temp', created_by, expiration_time),
            query_type='insert'
        )

        url_id = cursor.fetchone()[0]

        # Generate short URL from ID using Base62
        short_code = encoder.encode(url_id)

        # Update with actual short code
        db_execute_query(
            cursor,
            """
            UPDATE urls SET short_url = %s WHERE id = %s
            """,
            (short_code, url_id),
            query_type='update'
        )

        conn.commit()

        # Seed Redis cache immediately (write-through caching)
        redis_setex(
            f"url:{short_code}",
            Config.REDIS_TTL,
            original_url
        )

        full_short_url = f"{Config.BASE_URL}{short_code}"

        # Increment success metrics
        URL_CREATED.inc()
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='201').inc()

        response = jsonify({
            'short_url': full_short_url,
            'original_url': original_url,
            'expires_at': expiration_time.isoformat() if expiration_time else None
        })
        response.headers.add("Access-Control-Allow-Origin", "*")
        return response, 201

    except psycopg2.Error as e:
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='500').inc()
        URL_CREATION_ERRORS.labels(error_type='DatabaseError').inc()
        if conn:
            conn.rollback()
        return jsonify({'error': f'Database error: {str(e)}'}), 500

    except redis.RedisError as e:
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='500').inc()
        URL_CREATION_ERRORS.labels(error_type='RedisError').inc()
        return jsonify({'error': f'Cache error: {str(e)}'}), 500

    except Exception as e:
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='500').inc()
        URL_CREATION_ERRORS.labels(error_type='UnknownError').inc()
        return jsonify({'error': str(e)}), 500

    finally:
        if cursor:
            cursor.close()
        if conn:
            close_db_connection(conn)
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)


@app.route('/url/<short_code>', methods=['GET'])
def get_url_stats(short_code):
    """Get URL statistics with metrics tracking"""
    start_time = time.time()
    endpoint = 'get_url_stats'
    method = 'GET'

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        db_execute_query(
            cursor,
            """
            SELECT short_url, url, clicks, created_at, expiration_time, status
            FROM urls
            WHERE short_url = %s
            """,
            (short_code,),
            query_type='select'
        )

        result = cursor.fetchone()
        cursor.close()
        close_db_connection(conn)

        if not result:
            REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='404').inc()
            return jsonify({'error': 'URL not found'}), 404

        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='200').inc()
        return jsonify({
            'short_code': result[0],
            'original_url': result[1],
            'clicks': result[2],
            'created_at': result[3].isoformat() if result[3] else None,
            'expires_at': result[4].isoformat() if result[4] else None,
            'status': result[5]
        }), 200

    except Exception as e:
        print(f"Error getting URL stats: {e}")
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='500').inc()
        return jsonify({'error': str(e)}), 500
    finally:
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
