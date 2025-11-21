# Agent Memz: The Wordz v0.1

A **first-class memory backend** for voice agents, combining vector search, graph databases, caching, and object storage for intelligent, contextual memory recall.

## 🚀 Overview

Agent Memz provides a production-ready memory layer that enables voice agents to:

- 🧠 **Remember conversations** with semantic understanding
- 🔍 **Search memories** using natural language queries
- 🕸️ **Map relationships** between concepts, entities, and facts
- ⚡ **Retrieve instantly** with multi-tier caching
- 🎙️ **Store audio** with transcriptions and metadata
- 📊 **Track patterns** and user preferences over time

## 🏗️ Architecture

**Tech Stack:**
- **PostgreSQL** + **pgvector** - Vector similarity search
- **Apache AGE** - Graph database for relationships
- **Redis** - High-speed caching layer
- **MinIO** - S3-compatible object storage for audio files
- **Python** - Service layer implementation

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed system design.

## 📋 Prerequisites

- **Docker & Docker Compose** (recommended)
- **Python 3.9+**
- **PostgreSQL 15+** (if not using Docker)
- **OpenAI API key** (for embeddings) or local embedding model

## 🎯 Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/klogins-hash/agent-memz-the-wordz-v0.1.git
cd agent-memz-the-wordz-v0.1

# Copy environment template
cp .env.example .env

# Edit .env and add your API keys
# At minimum, set your OPENAI_API_KEY
```

### 2. Start Infrastructure with Docker

```bash
# Start all services (PostgreSQL, Redis, MinIO)
docker-compose up -d

# Check service health
docker-compose ps

# View logs
docker-compose logs -f
```

**Services will be available at:**
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`
- MinIO API: `localhost:9000`
- MinIO Console: `http://localhost:9001` (admin/admin)

### 3. Install Python Dependencies

```bash
# Create virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 4. Verify Database Setup

```bash
# Connect to PostgreSQL
psql -h localhost -U agentmemz -d agent_memory

# Check installed extensions
\dx

# You should see: vector, uuid-ossp, age

# View tables
\dt

# Exit
\q
```

### 5. Run Example Usage

```bash
# Test the memory service
python src/memory_service.py
```

## 💡 Usage Examples

### Basic Memory Operations

```python
from src.memory_service import MemoryService

# Initialize service
service = MemoryService()

# Create a conversation
conversation_id = service.create_conversation(
    user_id="user_123",
    session_id="session_abc"
)

# Add a message with automatic embedding
message = service.add_message(
    conversation_id=conversation_id,
    role="user",
    content="I love hiking in the mountains and photography"
)

# Extract and store facts
facts = service.extract_and_store_facts(
    user_id="user_123",
    content="User enjoys outdoor activities",
    message_id=message['message_id'],
    fact_type='preference'
)

# Find similar memories
similar = service.find_similar_memories(
    query="What outdoor activities does the user enjoy?",
    user_id="user_123",
    limit=5
)

print(f"Found {len(similar)} similar memories")
for memory in similar:
    print(f"- {memory['content']} (similarity: {memory['similarity']:.2f})")
```

### Storing Audio Files

```python
# Store audio in MinIO
with open('audio.wav', 'rb') as f:
    audio_data = f.read()

audio_url = service.store_audio(
    user_id="user_123",
    session_id="session_abc",
    audio_data=audio_data,
    filename="recording_001.wav"
)

# Add message with audio reference
service.add_message(
    conversation_id=conversation_id,
    role="user",
    content="Transcribed text here",
    audio_url=audio_url
)
```

### Graph Queries (Apache AGE)

```python
# Query relationships in the knowledge graph
results = service.query_graph("""
    MATCH (p:Person)-[:MENTIONS]->(t:Topic)
    RETURN p.name, t.name, COUNT(*) as mentions
    ORDER BY mentions DESC
    LIMIT 10
""")
```

### Session Context Management

```python
# Get active session context from Redis
context = service.get_session_context("session_abc")

# Update session context
service.update_session_context(
    session_id="session_abc",
    context_updates={
        'current_topic': 'travel',
        'mood': 'enthusiastic',
        'intent': 'planning'
    }
)
```

## 🗂️ Project Structure

```
agent-memz-the-wordz-v0.1/
├── src/
│   └── memory_service.py      # Main memory service implementation
├── scripts/
│   ├── init-db.sql            # Database schema initialization
│   └── install-age.sh         # Apache AGE installation
├── docker-compose.yml         # Infrastructure services
├── requirements.txt           # Python dependencies
├── .env.example              # Environment template
├── ARCHITECTURE.md           # Detailed architecture docs
└── README.md                 # This file
```

## 🔧 Configuration

### Environment Variables

Key variables in `.env`:

```bash
# Required
OPENAI_API_KEY=sk-...                    # For embeddings
POSTGRES_PASSWORD=your_secure_password   # Database password
MINIO_ROOT_PASSWORD=your_minio_password  # Object storage password

# Optional (defaults provided)
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
REDIS_HOST=localhost
REDIS_PORT=6379
MINIO_ENDPOINT=localhost:9000
```

See `.env.example` for all available options.

## 📊 Database Schema

**Key Tables:**
- `conversations` - Conversation sessions
- `messages` - Individual messages with embeddings
- `memory_facts` - Extracted facts with vector search
- `voice_profiles` - Voice characteristics
- `semantic_clusters` - Grouped related memories

**Custom Functions:**
- `find_similar_messages()` - Vector similarity search
- `find_similar_facts()` - User-scoped memory retrieval
- `update_fact_access()` - Access tracking

See [scripts/init-db.sql](scripts/init-db.sql) for complete schema.

## 🧪 Testing

```bash
# Run tests
pytest

# With coverage
pytest --cov=src --cov-report=html

# Specific test
pytest tests/test_memory_service.py
```

## 🔍 Monitoring

### Check Service Health

```bash
# PostgreSQL
docker-compose exec postgres pg_isready

# Redis
docker-compose exec redis redis-cli ping

# MinIO
curl http://localhost:9000/minio/health/live
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f postgres
docker-compose logs -f redis
docker-compose logs -f minio
```

### Database Queries

```sql
-- Recent conversations
SELECT * FROM recent_conversations LIMIT 10;

-- User memory summary
SELECT * FROM user_memory_summary WHERE user_id = 'user_123';

-- Vector search performance
EXPLAIN ANALYZE
SELECT * FROM find_similar_facts(
    '[...]'::vector(1536),
    'user_123',
    0.7,
    10
);
```

## 🛠️ Development

```bash
# Format code
black src/

# Lint
flake8 src/

# Type check
mypy src/

# Start services in development
docker-compose up

# Stop services
docker-compose down

# Reset everything (⚠️ deletes all data)
docker-compose down -v
```

## 🔐 Security

- **Secrets Management**: All credentials in `.env` (git-ignored)
- **Data Encryption**: TLS for all external connections
- **Access Control**: Row-level security on user data
- **PII Handling**: Optional redaction before embeddings
- **Audit Trail**: All interactions logged in `interaction_analytics`

## 📈 Performance

**Typical Latencies:**
- Cache hit (Redis): < 5ms
- Vector search (PostgreSQL): 10-50ms
- Graph traversal (AGE): 20-100ms
- Embedding generation: 100-500ms (cached: < 5ms)
- Audio upload (MinIO): 50-200ms

**Optimization Tips:**
- Enable Redis caching for embeddings
- Use appropriate similarity thresholds (0.6-0.8)
- Partition tables by date for large datasets
- Regular `VACUUM` and `ANALYZE` on PostgreSQL

See [ARCHITECTURE.md](ARCHITECTURE.md) for scaling strategies.

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📝 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Built with:
- [pgvector](https://github.com/pgvector/pgvector) - Vector similarity search
- [Apache AGE](https://age.apache.org/) - Graph database extension
- [MinIO](https://min.io/) - Object storage
- [Redis](https://redis.io/) - Caching layer

## 📚 Additional Resources

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed system architecture
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings) - Embedding API
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Apache AGE Documentation](https://age.apache.org/age-manual/master/intro/overview.html)

## 🐛 Troubleshooting

**Services won't start:**
```bash
# Check ports are available
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis
lsof -i :9000  # MinIO
```

**Database connection errors:**
```bash
# Verify PostgreSQL is ready
docker-compose exec postgres pg_isready -U agentmemz
```

**Permission errors on scripts:**
```bash
chmod +x scripts/*.sh
```

**MinIO bucket access:**
- Login to console: http://localhost:9001
- Default credentials: minioadmin / minioadmin123
- Check bucket policies and access keys

---

**Questions or issues?** Open an issue on GitHub or check the [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.
