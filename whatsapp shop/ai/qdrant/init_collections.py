"""
Initialize Qdrant collections with appropriate configurations for the WhatsApp shop.
"""
import os
from qdrant_client import QdrantClient
from qdrant_client.http import models
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Qdrant client
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")

client = QdrantClient(
    url=QDRANT_URL,
    api_key=QDRANT_API_KEY if QDRANT_API_KEY else None,
    timeout=30.0
)

def init_products_collection():
    """Initialize the products vector collection."""
    collection_name = "products"
    
    # Check if collection exists
    collections = client.get_collections().collections
    collection_names = [collection.name for collection in collections]
    
    if collection_name in collection_names:
        print(f"Collection '{collection_name}' already exists. Skipping creation.")
        return
    
    # Create collection with vector configuration
    client.create_collection(
        collection_name=collection_name,
        vectors_config={
            "text": models.VectorParams(
                size=768,  # Dimension of the vectors
                distance=models.Distance.COSINE,
            ),
            "image": models.VectorParams(
                size=512,  # Dimension for image embeddings
                distance=models.Distance.COSINE,
            )
        },
        # Enable payload indexing for faster filtering
        optimizers_config={
            "default_segment_number": 2,
            "indexing_threshold": 0,
        },
    )
    
    # Create payload index for faster filtering
    client.create_payload_index(
        collection_name=collection_name,
        field_name="category",
        field_schema=models.PayloadSchemaType.KEYWORD,
    )
    
    client.create_payload_index(
        collection_name=collection_name,
        field_name="price",
        field_schema=models.PayloadSchemaType.FLOAT,
    )
    
    print(f"Created collection '{collection_name}' with vector and payload indexing")

def init_faqs_collection():
    """Initialize the FAQs vector collection."""
    collection_name = "faqs"
    
    # Check if collection exists
    collections = client.get_collections().collections
    collection_names = [collection.name for collection in collections]
    
    if collection_name in collection_names:
        print(f"Collection '{collection_name}' already exists. Skipping creation.")
        return
    
    # Create collection with vector configuration
    client.create_collection(
        collection_name=collection_name,
        vectors_config={
            "text": models.VectorParams(
                size=768,  # Dimension of the vectors
                distance=models.Distance.COSINE,
            )
        },
        optimizers_config={
            "default_segment_number": 2,
        },
    )
    
    # Create payload index for faster filtering
    client.create_payload_index(
        collection_name=collection_name,
        field_name="category",
        field_schema=models.PayloadSchemaType.KEYWORD,
    )
    
    print(f"Created collection '{collection_name}' with vector and payload indexing")

def init_policies_collection():
    """Initialize the policies vector collection."""
    collection_name = "policies"
    
    # Check if collection exists
    collections = client.get_collections().collections
    collection_names = [collection.name for collection in collections]
    
    if collection_name in collection_names:
        print(f"Collection '{collection_name}' already exists. Skipping creation.")
        return
    
    # Create collection with vector configuration
    client.create_collection(
        collection_name=collection_name,
        vectors_config={
            "text": models.VectorParams(
                size=768,  # Dimension of the vectors
                distance=models.Distance.COSINE,
            )
        },
        optimizers_config={
            "default_segment_number": 2,
        },
    )
    
    # Create payload index for faster filtering
    client.create_payload_index(
        collection_name=collection_name,
        field_name="policy_type",
        field_schema=models.PayloadSchemaType.KEYWORD,
    )
    
    client.create_payload_index(
        collection_name=collection_name,
        field_name="version",
        field_schema=models.PayloadSchemaType.INTEGER,
    )
    
    print(f"Created collection '{collection_name}' with vector and payload indexing")

def main():
    """Initialize all Qdrant collections."""
    print("Initializing Qdrant collections...")
    
    try:
        # Initialize all collections
        init_products_collection()
        init_faqs_collection()
        init_policies_collection()
        
        print("\nAll collections initialized successfully!")
        print("\nCollection details:")
        collections = client.get_collections()
        for collection in collections.collections:
            print(f"- {collection.name}: {collection.vectors_count} vectors")
            
    except Exception as e:
        print(f"Error initializing collections: {str(e)}")
        return 1
    
    return 0

if __name__ == "__main__":
    main()
