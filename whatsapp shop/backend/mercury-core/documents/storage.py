from minio import Minio
from minio.error import S3Error
from datetime import timedelta
from typing import Optional
import io

from app.core.config import settings
from app.core.logging import setup_logging

logger = setup_logging()

class MinIOStorage:
    
    def __init__(self):
        self.client = Minio(
            settings.MINIO_ENDPOINT,
            access_key=settings.MINIO_ACCESS_KEY,
            secret_key=settings.MINIO_SECRET_KEY,
            secure=settings.MINIO_SECURE
        )
        self._ensure_buckets()
    
    def _ensure_buckets(self):
        """Ensure required buckets exist"""
        buckets = [
            settings.MINIO_BUCKET_DOCUMENTS,
            settings.MINIO_BUCKET_DIGITAL_PRODUCTS,
            settings.MINIO_BUCKET_REPORTS
        ]
        
        for bucket in buckets:
            try:
                if not self.client.bucket_exists(bucket):
                    self.client.make_bucket(bucket)
                    logger.info(f"Created MinIO bucket: {bucket}")
            except S3Error as e:
                logger.error(f"Error creating bucket {bucket}: {e}")
    
    def upload(
        self,
        bucket: str,
        object_name: str,
        data: bytes,
        content_type: str = "application/octet-stream"
    ) -> str:
        """Upload file to MinIO"""
        
        try:
            self.client.put_object(
                bucket,
                object_name,
                io.BytesIO(data),
                len(data),
                content_type=content_type
            )
            
            # Generate URL
            url = f"http://{settings.MINIO_ENDPOINT}/{bucket}/{object_name}"
            logger.info(f"File uploaded: {object_name}")
            return url
            
        except S3Error as e:
            logger.error(f"Upload error: {e}")
            raise
    
    def get_presigned_url(
        self,
        bucket: str,
        object_name: str,
        expires: timedelta = timedelta(hours=24)
    ) -> str:
        """Generate temporary download URL"""
        
        try:
            url = self.client.presigned_get_object(bucket, object_name, expires=expires)
            return url
        except S3Error as e:
            logger.error(f"Error generating presigned URL: {e}")
            raise
    
    def download(self, bucket: str, object_name: str) -> bytes:
        """Download file from MinIO"""
        
        try:
            response = self.client.get_object(bucket, object_name)
            data = response.read()
            response.close()
            response.release_conn()
            return data
        except S3Error as e:
            logger.error(f"Download error: {e}")
            raise
    
    def delete(self, bucket: str, object_name: str) -> bool:
        """Delete file from MinIO"""
        
        try:
            self.client.remove_object(bucket, object_name)
            logger.info(f"File deleted: {object_name}")
            return True
        except S3Error as e:
            logger.error(f"Delete error: {e}")
            return False