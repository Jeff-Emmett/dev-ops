---
id: task-13
title: Migrate from Qdrant to PostgreSQL + pgVector
status: To Do
assignee: []
created_date: '2025-12-04 11:30'
labels: [infrastructure, database, migration]
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate vector database infrastructure from Qdrant to PostgreSQL + pgVector extension. This consolidates the database stack, reduces operational complexity, and enables unified Django ORM access for both relational and vector data.

**Current State:**
- Qdrant running on Netcup RS 8000 (port 6333)
- Used by: hyperindex-system, semantic-search, gaia
- Embedding dimensions: 768 (nomic-embed-text), 384 (all-MiniLM-L6-v2)
- PostgreSQL already in use by digital-knowledge-organizer (Django)

**Target State:**
- Single PostgreSQL 16 instance with pgVector extension
- Django ORM with django-pgvector for all vector operations
- Unified API through digital-knowledge-organizer backend
- Qdrant deprecated and removed

**Benefits:**
- Single database to manage (simplified ops)
- ACID transactions across vectors + metadata
- Native Django integration
- Lower memory footprint (no separate Qdrant process)
- Unified backup/restore strategy
<!-- SECTION:DESCRIPTION:END -->

## Plan

### Phase 1: PostgreSQL + pgVector Setup (Foundation)

#### 1.1 Install pgVector Extension
```bash
# On Netcup RS 8000 - update PostgreSQL container
ssh netcup "cd /opt/digital-knowledge-organizer && cat docker-compose.yml"

# Option A: Use official postgres image with pgvector
# Change image to: pgvector/pgvector:pg16

# Option B: Install extension in existing container
ssh netcup "docker exec -it postgres psql -U devuser -d digital_knowledge -c 'CREATE EXTENSION IF NOT EXISTS vector;'"
```

#### 1.2 Verify pgVector Installation
```sql
-- Check extension is installed
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Test vector operations
CREATE TABLE test_vectors (
    id SERIAL PRIMARY KEY,
    embedding vector(768)
);

INSERT INTO test_vectors (embedding) VALUES ('[0.1, 0.2, ...]'::vector);
DROP TABLE test_vectors;
```

#### 1.3 Create Vector Indexes
```sql
-- HNSW index for fast approximate nearest neighbor search
-- Recommended for most use cases (faster queries, slightly less accurate)
CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops);

-- IVFFlat index (alternative - faster inserts, requires training)
-- CREATE INDEX ON embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

---

### Phase 2: Django Integration

#### 2.1 Install django-pgvector
```bash
# In digital-knowledge-organizer
cd /home/jeffe/Github/digital-knowledge-organizer
pip install django-pgvector
# Add to requirements.txt: django-pgvector>=0.1.0
```

#### 2.2 Configure Django Settings
```python
# config/settings.py
INSTALLED_APPS = [
    ...
    'pgvector.django',  # Add pgvector Django integration
]

# Ensure PostgreSQL is configured (already done)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        ...
    }
}
```

#### 2.3 Create Vector Models
```python
# Create new app: embeddings/models.py
from django.db import models
from pgvector.django import VectorField, HnswIndex

class Embedding(models.Model):
    """Base embedding model for all vector data"""
    content_type = models.CharField(max_length=50)  # 'discovery', 'document', 'query'
    content_id = models.CharField(max_length=255)   # Reference to source
    embedding = VectorField(dimensions=768)          # nomic-embed-text dimension
    metadata = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            HnswIndex(
                name='embedding_hnsw_idx',
                fields=['embedding'],
                m=16,
                ef_construction=64,
                opclasses=['vector_cosine_ops'],
            ),
        ]

class Discovery(models.Model):
    """Migrated from hyperindex-system Qdrant collection"""
    url = models.URLField(unique=True)
    title = models.CharField(max_length=500)
    content = models.TextField()
    embedding = VectorField(dimensions=768)
    hyperindex_id = models.CharField(max_length=100, null=True)
    discovered_at = models.DateTimeField()
    metadata = models.JSONField(default=dict)

    class Meta:
        indexes = [
            HnswIndex(
                name='discovery_embedding_idx',
                fields=['embedding'],
                opclasses=['vector_cosine_ops'],
            ),
        ]

class SemanticDocument(models.Model):
    """Migrated from semantic-search Qdrant collection"""
    source = models.CharField(max_length=100)  # 'exa', 'local', etc.
    title = models.CharField(max_length=500)
    content = models.TextField()
    url = models.URLField(null=True)
    embedding = VectorField(dimensions=384)  # all-MiniLM-L6-v2 dimension
    metadata = models.JSONField(default=dict)
    indexed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            HnswIndex(
                name='semantic_doc_embedding_idx',
                fields=['embedding'],
                opclasses=['vector_cosine_ops'],
            ),
        ]
```

#### 2.4 Create Migration
```bash
python manage.py makemigrations embeddings
python manage.py migrate
```

#### 2.5 Add Vector Search API
```python
# embeddings/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from pgvector.django import CosineDistance
from .models import Discovery, SemanticDocument

class SimilaritySearchView(APIView):
    def post(self, request):
        query_embedding = request.data.get('embedding')
        collection = request.data.get('collection', 'discovery')
        limit = request.data.get('limit', 10)

        if collection == 'discovery':
            results = Discovery.objects.annotate(
                distance=CosineDistance('embedding', query_embedding)
            ).order_by('distance')[:limit]
        elif collection == 'semantic':
            results = SemanticDocument.objects.annotate(
                distance=CosineDistance('embedding', query_embedding)
            ).order_by('distance')[:limit]

        return Response({
            'results': [
                {
                    'id': r.id,
                    'title': r.title,
                    'url': r.url,
                    'distance': r.distance,
                    'metadata': r.metadata,
                }
                for r in results
            ]
        })
```

---

### Phase 3: Data Migration

#### 3.1 Export Qdrant Data
```python
# scripts/export_qdrant.py
from qdrant_client import QdrantClient
import json

client = QdrantClient(host="localhost", port=6333)

# Export hyperindex discoveries
discoveries = client.scroll(
    collection_name="discoveries",
    limit=10000,
    with_payload=True,
    with_vectors=True,
)

with open('qdrant_discoveries_export.json', 'w') as f:
    json.dump([{
        'id': point.id,
        'vector': point.vector,
        'payload': point.payload,
    } for point in discoveries[0]], f)

# Export semantic-search documents
documents = client.scroll(
    collection_name="documents",
    limit=10000,
    with_payload=True,
    with_vectors=True,
)

with open('qdrant_documents_export.json', 'w') as f:
    json.dump([{
        'id': point.id,
        'vector': point.vector,
        'payload': point.payload,
    } for point in documents[0]], f)

print(f"Exported {len(discoveries[0])} discoveries, {len(documents[0])} documents")
```

#### 3.2 Import to PostgreSQL
```python
# scripts/import_pgvector.py
import json
from django.utils import timezone
from embeddings.models import Discovery, SemanticDocument

# Import discoveries
with open('qdrant_discoveries_export.json', 'r') as f:
    discoveries = json.load(f)

for d in discoveries:
    Discovery.objects.create(
        url=d['payload'].get('url', ''),
        title=d['payload'].get('title', ''),
        content=d['payload'].get('content', ''),
        embedding=d['vector'],
        hyperindex_id=d['payload'].get('hyperindex_id'),
        discovered_at=d['payload'].get('discovered_at', timezone.now()),
        metadata=d['payload'],
    )

# Import semantic documents
with open('qdrant_documents_export.json', 'r') as f:
    documents = json.load(f)

for doc in documents:
    SemanticDocument.objects.create(
        source=doc['payload'].get('source', 'unknown'),
        title=doc['payload'].get('title', ''),
        content=doc['payload'].get('content', ''),
        url=doc['payload'].get('url'),
        embedding=doc['vector'],
        metadata=doc['payload'],
    )

print(f"Imported {len(discoveries)} discoveries, {len(documents)} documents")
```

#### 3.3 Verify Migration
```python
# scripts/verify_migration.py
from qdrant_client import QdrantClient
from embeddings.models import Discovery, SemanticDocument

# Compare counts
qdrant = QdrantClient(host="localhost", port=6333)

qdrant_discoveries = qdrant.count(collection_name="discoveries").count
pg_discoveries = Discovery.objects.count()

qdrant_docs = qdrant.count(collection_name="documents").count
pg_docs = SemanticDocument.objects.count()

print(f"Discoveries: Qdrant={qdrant_discoveries}, PostgreSQL={pg_discoveries}")
print(f"Documents: Qdrant={qdrant_docs}, PostgreSQL={pg_docs}")

# Test similarity search produces similar results
test_vector = [...]  # Use a real vector from the data
qdrant_results = qdrant.search(collection_name="discoveries", query_vector=test_vector, limit=5)
pg_results = Discovery.objects.annotate(
    distance=CosineDistance('embedding', test_vector)
).order_by('distance')[:5]

# Compare top results
```

---

### Phase 4: Update Client Applications

#### 4.1 Update hyperindex-system
```typescript
// packages/api/src/services/vector.ts
// Replace Qdrant calls with Django API calls

export class VectorService {
  private apiUrl: string;

  constructor() {
    this.apiUrl = process.env.DJANGO_API_URL || 'http://localhost:8000';
  }

  async search(embedding: number[], collection: string, limit: number = 10) {
    const response = await fetch(`${this.apiUrl}/api/embeddings/search/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ embedding, collection, limit }),
    });
    return response.json();
  }

  async upsert(id: string, embedding: number[], metadata: object, collection: string) {
    const response = await fetch(`${this.apiUrl}/api/embeddings/upsert/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, embedding, metadata, collection }),
    });
    return response.json();
  }
}
```

#### 4.2 Update semantic-search
```python
# Already Python - can use Django models directly or call API
from embeddings.models import SemanticDocument
from pgvector.django import CosineDistance

def search(query_embedding, limit=10):
    return SemanticDocument.objects.annotate(
        distance=CosineDistance('embedding', query_embedding)
    ).order_by('distance')[:limit]
```

#### 4.3 Update gaia (if still in use)
```typescript
// Create adapter for pgvector that matches Qdrant adapter interface
// packages/adapter-pgvector/src/index.ts
```

---

### Phase 5: Cleanup & Deprecation

#### 5.1 Remove Qdrant from Docker Compose
```yaml
# Comment out or remove Qdrant service from all docker-compose.yml files
# services:
#   qdrant:
#     image: qdrant/qdrant:latest
#     ...
```

#### 5.2 Update Environment Variables
```bash
# Remove Qdrant-related env vars
# QDRANT_URL=http://localhost:6333
# QDRANT_API_KEY=...

# Add Django API URL if not present
DJANGO_API_URL=http://localhost:8000
```

#### 5.3 Remove Qdrant Dependencies
```bash
# Python projects
pip uninstall qdrant-client
# Remove from requirements.txt

# Node.js projects
npm uninstall @qdrant/js-client-rest
# Remove from package.json
```

#### 5.4 Archive Qdrant Data (Safety Backup)
```bash
# Before deleting Qdrant container, backup the data
ssh netcup "docker exec qdrant tar -czf /qdrant/storage/backup.tar.gz /qdrant/storage"
ssh netcup "docker cp qdrant:/qdrant/storage/backup.tar.gz /opt/backups/qdrant-final-backup.tar.gz"
```

#### 5.5 Stop and Remove Qdrant
```bash
ssh netcup "docker stop qdrant && docker rm qdrant"
# Or via docker-compose
ssh netcup "cd /opt/semantic-search && docker compose down"
```

---

## Performance Considerations

### pgVector Index Tuning

```sql
-- For large datasets (>100k vectors), tune HNSW parameters
-- Higher m = more connections = better recall but more memory
-- Higher ef_construction = better index quality but slower builds

CREATE INDEX CONCURRENTLY discovery_embedding_hnsw
ON embeddings_discovery
USING hnsw (embedding vector_cosine_ops)
WITH (m = 24, ef_construction = 128);

-- At query time, set ef_search for recall/speed tradeoff
SET hnsw.ef_search = 100;  -- Default is 40
```

### Query Optimization

```python
# Use select_related/prefetch_related to avoid N+1 queries
results = Discovery.objects.annotate(
    distance=CosineDistance('embedding', query_embedding)
).select_related('hyperindex').order_by('distance')[:limit]

# For hybrid search (vector + filters), use filtered index scan
results = Discovery.objects.filter(
    discovered_at__gte=start_date,
    metadata__source='exa'
).annotate(
    distance=CosineDistance('embedding', query_embedding)
).order_by('distance')[:limit]
```

### Memory & Storage Estimates

| Collection | Vectors | Dimensions | Estimated Size |
|------------|---------|------------|----------------|
| discoveries | ~10,000 | 768 | ~30 MB |
| documents | ~50,000 | 384 | ~75 MB |
| HNSW indexes | - | - | ~2x vector size |
| **Total** | - | - | ~200-300 MB |

PostgreSQL can easily handle this. For 1M+ vectors, consider partitioning.

---

## Cloudflare D1 Note

**D1 is NOT compatible with Django or pgVector.**

D1 is SQLite-based and runs only on Cloudflare Workers (JavaScript runtime). Options:

1. **Keep D1 for edge auth** - canvas-website auth stays on D1
2. **Use Cloudflare Hyperdrive** - Connect Workers to PostgreSQL for non-auth data
3. **API Bridge** - Workers call Django API for database operations

Recommended: Keep D1 for lightweight edge auth, use Django/PostgreSQL for everything else.

---

## Rollback Plan

If migration fails or performance is unacceptable:

1. Qdrant data backup exists at `/opt/backups/qdrant-final-backup.tar.gz`
2. Restore Qdrant container: `docker run -d -p 6333:6333 -v qdrant_data:/qdrant/storage qdrant/qdrant`
3. Revert client code changes (git revert)
4. Re-enable Qdrant environment variables

---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 pgVector extension installed and verified on PostgreSQL
- [ ] #2 Django models created for Discovery and SemanticDocument
- [ ] #3 All Qdrant data exported and imported to PostgreSQL
- [ ] #4 Vector search API endpoints working (similarity search)
- [ ] #5 hyperindex-system updated to use Django API
- [ ] #6 semantic-search updated to use pgVector
- [ ] #7 Qdrant container stopped and removed
- [ ] #8 Performance benchmarks show acceptable query times (<100ms for top-10)
- [ ] #9 Documentation updated with new architecture
<!-- AC:END -->

## Notes

**Resources:**
- pgVector docs: https://github.com/pgvector/pgvector
- django-pgvector: https://github.com/pgvector/pgvector-python#django
- Migration guide: https://qdrant.tech/documentation/guides/migration/

**Estimated effort:** Medium-High (involves multiple services)

**Risk:** Low-Medium (data can be backed up, rollback plan exists)
