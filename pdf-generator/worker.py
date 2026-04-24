import json
import boto3
import redis
import psycopg2
from io import BytesIO
from xhtml2pdf import pisa
import os

# --- Configurations ---
REDIS_HOST = os.getenv("REDIS_HOST", "cache")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))

REDIS_CONN = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

s3s = boto3.client(
    's3',
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=os.getenv("AWS_DEFAULT_REGION", "us-east-1")
)
BUCKET_NAME = "pdf-generator-sandesh"
QUEUE_NAME = "job_queue"

DB_CONFIG = os.getenv("DATABASE_URL", "postgresql://user:password@db:5432/mydatabase")


def update_job_status(job_id, status, download_url=None):
    """Updates status and download_url in the PostgreSQL 'jobs' table."""
    try:
        conn = psycopg2.connect(DB_CONFIG)
        cur = conn.cursor()

        # Updated query to handle the download_url column
        if download_url:
            query = "UPDATE jobs SET status = %s, download_url = %s WHERE job_id = %s"
            cur.execute(query, (status, download_url, job_id))
        else:
            query = "UPDATE jobs SET status = %s WHERE job_id = %s"
            cur.execute(query, (status, job_id))

        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"❌ DB Update Failed: {e}")


def process_worker():
    print(f"🚀 Worker ready. Watching {QUEUE_NAME}...")
    while True:
        result = REDIS_CONN.brpop(QUEUE_NAME, timeout=0)
        if result:
            _, raw_data = result
            payload = json.loads(raw_data)
            job_id = payload['job_id']
            print(f"Processing Job: {job_id}")

            params = payload['data'].get('params', {})
            update_job_status(job_id, "processing")

            try:
                # 1. Create PDF from params
                html = f"<h1>Job {job_id}</h1><p>{json.dumps(params)}</p>"
                pdf_buffer = BytesIO()
                pisa.CreatePDF(html, dest=pdf_buffer)
                pdf_buffer.seek(0)

                # 2. Upload to S3
                s3_key = f"outputs/{job_id}.pdf"
                s3s.upload_fileobj(pdf_buffer, BUCKET_NAME, s3_key)

                # 3. Generate Pre-signed URL (Expires in 1 hour)
                presigned_url = s3s.generate_presigned_url(
                    'get_object',
                    Params={'Bucket': BUCKET_NAME, 'Key': s3_key},
                    ExpiresIn=3600
                )

                # 4. Finalize with URL
                update_job_status(job_id, "completed", download_url=presigned_url)
                print(f"✅ Job {job_id} completed and URL generated.")

            except Exception as e:
                print(f"❌ Job {job_id} error: {e}")
                update_job_status(job_id, "failed")


if __name__ == "__main__":
    process_worker()
