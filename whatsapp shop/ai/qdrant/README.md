# Qdrant Vector Database Setup

This directory contains the configuration and initialization scripts for the Qdrant vector database used in the WhatsApp shop application.

## Collections

1. **products**
   - Stores product embeddings for semantic search and recommendations
   - Vector types:
     - `text`: 768-dimensional text embeddings
     - `image`: 512-dimensional image embeddings
   - Indexed fields: `category`, `price`

2. **faqs**
   - Stores FAQ embeddings for quick question-answering
   - Vector type: `text` (768-dimensional)
   - Indexed field: `category`

3. **policies**
   - Stores policy documents and their embeddings
   - Vector type: `text` (768-dimensional)
   - Indexed fields: `policy_type`, `version`

## Setup

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Create a `.env` file with your Qdrant configuration:
   ```env
   QDRANT_URL=http://localhost:6333
   QDRANT_API_KEY=your-api-key-if-required
   ```

3. Initialize the collections:
   ```bash
   python init_collections.py
   ```

## Usage

### Adding Data

```python
from qdrant_client import QdrantClient
import numpy as np

client = QdrantClient("localhost", port=6333)

# Add a product
client.upsert(
    collection_name="products",
    points=[
        {
            "id": 1,
            "vector": {
                "text": [0.1, 0.2, ..., 0.768],  # Your 768-dim text embedding
                "image": [0.5, 0.6, ..., 0.512]   # Your 512-dim image embedding
            },
            "payload": {
                "name": "Wireless Earbuds",
                "category": "electronics",
                "price": 99.99,
                "description": "High-quality wireless earbuds with noise cancellation"
            }
        }
    ]
)
```

### Querying Data

```python
# Semantic search
hits = client.search(
    collection_name="products",
    query_vector=("text", [0.1, 0.2, ...]),  # Your query embedding
    limit=5,
    with_vectors=False,
    with_payload=True
)

for hit in hits:
    print(hit.payload, "score:", hit.score)
```

## Maintenance

- **Backup**: Regularly back up your Qdrant data directory
- **Monitoring**: Monitor collection sizes and performance
- **Versioning**: Update the collection version in the payload when making schema changes
