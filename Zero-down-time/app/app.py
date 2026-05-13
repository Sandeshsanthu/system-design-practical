import time
import psycopg2
from psycopg2 import OperationalError


print("🚀 Application launched. Connecting to PgBouncer...")

conn_params = "host=pgbouncer port=6432 dbname=prod_db user=app_user password=SecretPassword123 connect_timeout=3"
while True:
    try:
        with psycopg2.connect(conn_params) as conn:
            with conn.cursor() as cur:
                cur.execute("CREATE TABLE IF NOT EXISTS orders (id SERIAL PRIMARY KEY, created_at TIMESTAMP DEFAULT NOW());")
                conn.commit()
                print("✅ Core database table ready.")
                break
    except OperationalError:
        print("⏳ Waiting for database proxy to be healthy...")
        time.sleep(2)
order_count = 0
while True:
    start_time = time.time()
    try:
        with psycopg2.connect(conn_params) as conn:
            with conn.cursor() as cur:
                cur.execute("INSERT INTO orders DEFAULT VALUES RETURNING id;")
                order_id = cur.fetchone()[0]
                conn.commit()
                latency = (time.time() - start_time) * 1000
                print(f"📦 Order #{order_id} placed successfully | Latency: {latency:.2f}ms")
                order_count += 1
        time.sleep(0.2)  # High throughput simulation
    except Exception as e:
        # A true production app should log exceptions but never crash
        latency = (time.time() - start_time) * 1000
        print(f"🚨 CRITICAL ERROR: Application execution blocked after {latency:.2f}ms | Details: {e}")
        time.sleep(0.5)
