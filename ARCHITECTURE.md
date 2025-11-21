# Agent Memz Architecture

## Overview

Agent Memz is a first-class memory backend for voice agents, combining vector search, graph databases, caching, and object storage for optimal performance and intelligent memory recall.

## Technology Stack

### Core Components

1. **PostgreSQL** - Primary relational database
2. **pgvector** - Vector similarity search for semantic memory
3. **Apache AGE** - Graph database for relationship mapping
4. **Redis** - High-speed caching and session management
5. **MinIO** - S3-compatible object storage for audio/files

## Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                    Voice Agent Layer                     │
│              (Your AI Agent Application)                 │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  Memory Service Layer                    │
│         (Python/Node.js API - Your Code)                │
│  - Query Router                                          │
│  - Embedding Generator                                   │
│  - Memory Consolidator                                   │
└─────────────────────────────────────────────────────────┘
                            ↓
          ┌─────────────────┴─────────────────┐
          ↓                 ↓                  ↓
    ┌─────────┐      ┌──────────┐      ┌──────────┐
    │  Redis  │      │PostgreSQL│      │  MinIO   │
    │ (Cache) │      │  +Vector │      │ (Files)  │
    │         │      │  +Graph  │      │          │
    └─────────┘      └──────────┘      └──────────┘
```

## Data Flow Patterns

### 1. Storing a Voice Interaction

```
User Speech
    ↓
1. Audio → MinIO (raw audio storage)
    ↓
2. Transcription → Messages Table
    ↓
3. Generate Embedding → pgvector index
    ↓
4. Extract Facts → Memory Facts Table
    ↓
5. Build Relationships → Apache AGE Graph
    ↓
6. Cache Session → Redis
```

### 2. Recalling Relevant Memories

```
New Query
    ↓
1. Check Redis Cache (session context)
    ↓
2. Generate Query Embedding
    ↓
3. Vector Search (pgvector) → Similar memories
    ↓
4. Graph Traversal (AGE) → Related concepts
    ↓
5. Rank & Filter → Top K memories
    ↓
6. Cache Results → Redis
```

## Component Deep Dive

### PostgreSQL with pgvector

**Purpose**: Semantic similarity search using vector embeddings

**Tables Using Vectors**:
- `messages.embedding` - Message content embeddings (1536 dimensions)
- `memory_facts.embedding` - Extracted fact embeddings (1536 dimensions)
- `voice_profiles.voice_embedding` - Voice characteristic embeddings (512 dimensions)
- `semantic_clusters.centroid_embedding` - Cluster representations (1536 dimensions)

**Key Operations**:
- Cosine similarity search: `embedding <=> query_embedding`
- HNSW index for fast approximate nearest neighbor search
- Custom functions: `find_similar_messages()`, `find_similar_facts()`

**Use Cases**:
- "Find conversations about travel plans"
- "What has the user said about their family?"
- "Retrieve similar past interactions"

### Apache AGE (Graph Database)

**Purpose**: Model complex relationships between memories, concepts, and entities

**Graphs Created**:
1. `memory_graph` - Relationships between facts, concepts, and entities
2. `conversation_graph` - Flow and connections between conversations

**Node Types**:
- `Person` - Mentioned individuals
- `Topic` - Discussion topics
- `Fact` - Extracted information
- `Concept` - Abstract ideas
- `Location` - Geographic references
- `Preference` - User preferences

**Relationship Types**:
- `RELATES_TO` - General relationships
- `MENTIONS` - Entity mentions
- `FOLLOWS_FROM` - Conversation flow
- `CONTRADICTS` - Conflicting information
- `SUPPORTS` - Supporting evidence
- `PART_OF` - Hierarchical relationships

**Use Cases**:
- "Show me all topics related to work projects"
- "Find conflicting preferences"
- "What entities are most frequently mentioned?"
- "Trace conversation topic evolution"

### Redis

**Purpose**: High-speed caching and real-time session management

**Data Structures**:

1. **Session Cache** (Hash)
   ```
   Key: session:{session_id}
   Fields: user_id, current_topic, context, last_activity
   TTL: 1 hour
   ```

2. **Recent Memories** (Sorted Set)
   ```
   Key: recent:{user_id}
   Score: timestamp
   Members: fact_ids
   TTL: 24 hours
   ```

3. **Embedding Cache** (String)
   ```
   Key: embedding:{content_hash}
   Value: serialized embedding vector
   TTL: 7 days
   ```

4. **Query Results** (List)
   ```
   Key: query:{query_hash}
   Value: [fact_id1, fact_id2, ...]
   TTL: 1 hour
   ```

**Use Cases**:
- Cache expensive embedding computations
- Maintain active conversation context
- Quick access to recent memories
- Rate limiting and analytics counters

### MinIO (Object Storage)

**Purpose**: Store large files (audio, transcriptions, backups)

**Bucket Structure**:

1. **audio-recordings** - Original voice recordings
   ```
   Path: audio-recordings/{user_id}/{session_id}/{timestamp}.wav
   Metadata: duration, sample_rate, speaker_id
   ```

2. **transcriptions** - Transcription files
   ```
   Path: transcriptions/{user_id}/{session_id}/{message_id}.json
   Content: {text, confidence, timestamps, entities}
   ```

3. **embeddings** - Batch embedding exports
   ```
   Path: embeddings/{user_id}/{date}/vectors.npy
   Purpose: Backup, analysis, transfer learning
   ```

4. **voice-profiles** - Voice biometric data
   ```
   Path: voice-profiles/{user_id}/profile.json
   Content: {characteristics, samples, model_params}
   ```

**Use Cases**:
- Store and retrieve audio recordings
- Maintain transcription history
- Export embeddings for analysis
- Voice authentication and personalization

## Memory Lifecycle

### Phase 1: Ingestion
1. Audio arrives from voice agent
2. Store in MinIO (audio-recordings bucket)
3. Transcribe and extract text
4. Store transcription in MinIO
5. Insert into `messages` table
6. Generate embedding (OpenAI/local model)
7. Update message with embedding

### Phase 2: Fact Extraction
1. Analyze message for meaningful facts
2. Extract entities, preferences, context
3. Generate fact embeddings
4. Insert into `memory_facts` table
5. Create graph nodes in Apache AGE
6. Link facts to entities/concepts

### Phase 3: Clustering
1. Calculate semantic similarity
2. Find or create appropriate cluster
3. Update cluster centroid
4. Create cluster membership
5. Update graph relationships

### Phase 4: Caching
1. Update active session in Redis
2. Cache recent memories
3. Invalidate stale queries
4. Update user context

### Phase 5: Retrieval
1. Parse incoming query
2. Check Redis cache first
3. Generate query embedding
4. Vector search for similar facts (pgvector)
5. Graph traversal for related concepts (AGE)
6. Combine and rank results
7. Cache result set in Redis
8. Update access tracking
9. Return to agent

## Query Strategy: Hybrid Retrieval

### Multi-Step Retrieval Process

```python
def retrieve_memory(query, user_id, k=10):
    # Step 1: Cache check
    cached = redis.get(f"query:{hash(query)}")
    if cached:
        return cached

    # Step 2: Vector similarity (pgvector)
    query_embedding = generate_embedding(query)
    vector_results = find_similar_facts(
        query_embedding,
        user_id,
        threshold=0.7,
        limit=20
    )

    # Step 3: Graph traversal (Apache AGE)
    graph_results = traverse_related_facts(
        vector_results,
        graph='memory_graph',
        depth=2
    )

    # Step 4: Combine and rerank
    combined = merge_results(vector_results, graph_results)
    ranked = rerank_by_relevance(combined, query)

    # Step 5: Cache and return
    redis.setex(f"query:{hash(query)}", 3600, ranked[:k])
    return ranked[:k]
```

## Performance Optimization

### Indexing Strategy
- **HNSW indexes** on all embedding columns for fast ANN search
- **B-tree indexes** on foreign keys and frequently queried columns
- **GiST indexes** for JSONB metadata queries
- **Partial indexes** for time-based queries (recent data)

### Caching Strategy
- **L1 Cache (Redis)**: Active sessions, recent queries (milliseconds)
- **L2 Cache (PostgreSQL)**: Indexed vector search (10-100ms)
- **L3 Storage (MinIO)**: Archival audio files (100+ms)

### Partitioning Strategy
- Partition `messages` by date (monthly)
- Partition `interaction_analytics` by timestamp
- Archive old data to MinIO after 90 days

## Scaling Considerations

### Horizontal Scaling
- **PostgreSQL**: Read replicas for query distribution
- **Redis**: Redis Cluster for distributed caching
- **MinIO**: Distributed mode for object storage
- **Application**: Stateless service layer

### Vertical Scaling
- **PostgreSQL**: Increase shared_buffers, work_mem for vector ops
- **Redis**: Increase maxmemory, use Redis Sentinel
- **MinIO**: SSD storage for hot data tier

## Security & Privacy

### Data Encryption
- At rest: MinIO encryption, PostgreSQL transparent encryption
- In transit: TLS for all connections
- Embeddings: Anonymize before external API calls

### Access Control
- Row-level security on all tables (user_id filtering)
- MinIO bucket policies (user-based access)
- Redis key namespacing by user

### PII Handling
- Detect and flag PII in transcriptions
- Optional redaction before embedding
- Audit trail in `interaction_analytics`

## Monitoring & Observability

### Key Metrics
- **Latency**: Query response time (p50, p95, p99)
- **Throughput**: Queries per second
- **Cache Hit Rate**: Redis cache effectiveness
- **Vector Search Accuracy**: Recall@k metrics
- **Storage Growth**: Database and MinIO size

### Health Checks
- PostgreSQL: Connection pool, slow queries
- Redis: Memory usage, eviction rate
- MinIO: Bucket size, API latency
- Embeddings: Generation time, API errors

## Example Queries

### Vector Search
```sql
-- Find similar messages
SELECT * FROM find_similar_messages(
    '[0.1, 0.2, ...]'::vector(1536),
    0.75,
    10
);
```

### Graph Traversal (Cypher via AGE)
```sql
-- Find all topics related to a person
SELECT * FROM cypher('memory_graph', $$
    MATCH (p:Person {name: 'John'})-[:DISCUSSES]->(t:Topic)
    RETURN t.name, COUNT(*) as mentions
    ORDER BY mentions DESC
$$) as (topic agtype, mentions agtype);
```

### Hybrid Query
```sql
-- Combine vector + graph
WITH similar_facts AS (
    SELECT * FROM find_similar_facts(
        '[...]'::vector(1536),
        'user123',
        0.7,
        20
    )
)
SELECT
    f.*,
    graph_data
FROM similar_facts f
LEFT JOIN get_fact_relationships(f.id) graph_data
ORDER BY f.similarity DESC
LIMIT 10;
```

## Development Workflow

1. **Start Services**: `docker-compose up -d`
2. **Check Health**: `docker-compose ps`
3. **View Logs**: `docker-compose logs -f postgres`
4. **Access MinIO Console**: http://localhost:9001
5. **Connect to DB**: `psql -h localhost -U agentmemz -d agent_memory`
6. **Redis CLI**: `redis-cli`

## Next Steps

1. Implement service layer in Python/Node.js
2. Create embedding pipeline
3. Build fact extraction logic
4. Implement graph builders
5. Create API endpoints
6. Add monitoring and logging
7. Performance testing and optimization
