"""
Agent Memz Memory Service
A first-class memory backend for voice agents
"""

import os
import hashlib
import json
from datetime import datetime
from typing import List, Dict, Optional, Any
import numpy as np

# Database and caching
import psycopg2
from psycopg2.extras import execute_values, RealDictCursor
import redis
from minio import Minio
from minio.error import S3Error

# For embeddings generation (example with OpenAI)
# You can swap this for local models like sentence-transformers
from openai import OpenAI


class MemoryService:
    """Main service for managing voice agent memory"""

    def __init__(self):
        # Initialize connections
        self.pg_conn = self._init_postgres()
        self.redis_client = self._init_redis()
        self.minio_client = self._init_minio()
        self.openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

    def _init_postgres(self) -> psycopg2.extensions.connection:
        """Initialize PostgreSQL connection"""
        return psycopg2.connect(
            host=os.getenv('POSTGRES_HOST', 'localhost'),
            port=os.getenv('POSTGRES_PORT', '5432'),
            database=os.getenv('POSTGRES_DB', 'agent_memory'),
            user=os.getenv('POSTGRES_USER', 'agentmemz'),
            password=os.getenv('POSTGRES_PASSWORD', 'devpassword')
        )

    def _init_redis(self) -> redis.Redis:
        """Initialize Redis connection"""
        return redis.Redis(
            host=os.getenv('REDIS_HOST', 'localhost'),
            port=int(os.getenv('REDIS_PORT', '6379')),
            decode_responses=False  # We'll handle binary data
        )

    def _init_minio(self) -> Minio:
        """Initialize MinIO client"""
        return Minio(
            os.getenv('MINIO_ENDPOINT', 'localhost:9000'),
            access_key=os.getenv('MINIO_ROOT_USER', 'minioadmin'),
            secret_key=os.getenv('MINIO_ROOT_PASSWORD', 'minioadmin123'),
            secure=os.getenv('MINIO_SECURE', 'false').lower() == 'true'
        )

    def generate_embedding(self, text: str, use_cache: bool = True) -> List[float]:
        """
        Generate embedding vector for text
        Uses Redis cache to avoid redundant API calls
        """
        # Create hash of text for caching
        text_hash = hashlib.md5(text.encode()).hexdigest()
        cache_key = f"embedding:{text_hash}"

        # Check cache first
        if use_cache:
            cached = self.redis_client.get(cache_key)
            if cached:
                return json.loads(cached)

        # Generate embedding via OpenAI
        response = self.openai_client.embeddings.create(
            model="text-embedding-ada-002",
            input=text
        )
        embedding = response.data[0].embedding

        # Cache for 7 days
        if use_cache:
            self.redis_client.setex(
                cache_key,
                7 * 24 * 60 * 60,
                json.dumps(embedding)
            )

        return embedding

    def store_audio(
        self,
        user_id: str,
        session_id: str,
        audio_data: bytes,
        filename: str = None
    ) -> str:
        """
        Store audio file in MinIO
        Returns the URL to access the audio
        """
        if filename is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{timestamp}.wav"

        object_name = f"{user_id}/{session_id}/{filename}"
        bucket_name = "audio-recordings"

        try:
            # Upload audio to MinIO
            from io import BytesIO
            self.minio_client.put_object(
                bucket_name,
                object_name,
                BytesIO(audio_data),
                length=len(audio_data),
                content_type='audio/wav'
            )

            # Generate presigned URL (valid for 7 days)
            url = self.minio_client.presigned_get_object(
                bucket_name,
                object_name,
                expires=7 * 24 * 60 * 60
            )
            return url

        except S3Error as e:
            print(f"Error uploading audio: {e}")
            raise

    def create_conversation(
        self,
        user_id: str,
        session_id: str,
        metadata: Dict = None
    ) -> str:
        """Create a new conversation session"""
        with self.pg_conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO conversations (user_id, session_id, metadata)
                VALUES (%s, %s, %s)
                RETURNING id
            """, (user_id, session_id, json.dumps(metadata or {})))

            conversation_id = cur.fetchone()['id']
            self.pg_conn.commit()

            # Cache active session in Redis
            session_key = f"session:{session_id}"
            self.redis_client.hset(session_key, mapping={
                'user_id': user_id,
                'conversation_id': str(conversation_id),
                'started_at': datetime.now().isoformat()
            })
            self.redis_client.expire(session_key, 3600)  # 1 hour TTL

            return str(conversation_id)

    def add_message(
        self,
        conversation_id: str,
        role: str,
        content: str,
        audio_url: Optional[str] = None,
        metadata: Dict = None
    ) -> Dict:
        """
        Add a message to a conversation
        Automatically generates and stores embedding
        """
        # Generate embedding
        embedding = self.generate_embedding(content)

        with self.pg_conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO messages (
                    conversation_id,
                    role,
                    content,
                    audio_url,
                    embedding,
                    metadata
                )
                VALUES (%s, %s, %s, %s, %s::vector, %s)
                RETURNING id, created_at
            """, (
                conversation_id,
                role,
                content,
                audio_url,
                embedding,
                json.dumps(metadata or {})
            ))

            result = cur.fetchone()
            self.pg_conn.commit()

            return {
                'message_id': str(result['id']),
                'created_at': result['created_at'].isoformat()
            }

    def extract_and_store_facts(
        self,
        user_id: str,
        content: str,
        message_id: str,
        fact_type: str = 'context'
    ) -> List[str]:
        """
        Extract facts from content and store in memory_facts table
        In production, use NLP/LLM for fact extraction
        This is a simplified example
        """
        # TODO: Implement sophisticated fact extraction
        # For now, store the entire content as a fact
        facts = [content]  # Replace with actual extraction logic

        fact_ids = []
        for fact_content in facts:
            embedding = self.generate_embedding(fact_content)

            with self.pg_conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO memory_facts (
                        user_id,
                        fact_type,
                        content,
                        embedding,
                        source_message_id
                    )
                    VALUES (%s, %s, %s, %s::vector, %s)
                    RETURNING id
                """, (user_id, fact_type, fact_content, embedding, message_id))

                fact_id = cur.fetchone()['id']
                self.pg_conn.commit()
                fact_ids.append(str(fact_id))

        return fact_ids

    def find_similar_memories(
        self,
        query: str,
        user_id: str,
        threshold: float = 0.7,
        limit: int = 10,
        use_cache: bool = True
    ) -> List[Dict]:
        """
        Find similar memories using vector similarity search
        Uses hybrid approach: cache -> vector search -> graph traversal
        """
        # Create query hash for caching
        query_hash = hashlib.md5(f"{query}:{user_id}".encode()).hexdigest()
        cache_key = f"query:{query_hash}"

        # Check cache first
        if use_cache:
            cached = self.redis_client.get(cache_key)
            if cached:
                return json.loads(cached)

        # Generate query embedding
        query_embedding = self.generate_embedding(query)

        # Perform vector similarity search
        with self.pg_conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM find_similar_facts(
                    %s::vector,
                    %s,
                    %s,
                    %s
                )
            """, (query_embedding, user_id, threshold, limit))

            results = cur.fetchall()

        # Convert to serializable format
        memories = [
            {
                'id': str(row['id']),
                'content': row['content'],
                'fact_type': row['fact_type'],
                'similarity': float(row['similarity']),
                'confidence': float(row['confidence_score'])
            }
            for row in results
        ]

        # Cache results for 1 hour
        if use_cache:
            self.redis_client.setex(
                cache_key,
                3600,
                json.dumps(memories)
            )

        # Update access tracking
        for memory in memories:
            self._update_fact_access(memory['id'])

        return memories

    def _update_fact_access(self, fact_id: str):
        """Update fact access count and timestamp"""
        with self.pg_conn.cursor() as cur:
            cur.execute("SELECT update_fact_access(%s)", (fact_id,))
            self.pg_conn.commit()

    def get_session_context(self, session_id: str) -> Optional[Dict]:
        """Get current session context from Redis"""
        session_key = f"session:{session_id}"
        session_data = self.redis_client.hgetall(session_key)

        if not session_data:
            return None

        return {
            k.decode(): v.decode()
            for k, v in session_data.items()
        }

    def update_session_context(
        self,
        session_id: str,
        context_updates: Dict
    ):
        """Update session context in Redis"""
        session_key = f"session:{session_id}"
        self.redis_client.hset(
            session_key,
            mapping={
                k: json.dumps(v) if isinstance(v, (dict, list)) else str(v)
                for k, v in context_updates.items()
            }
        )
        self.redis_client.expire(session_key, 3600)

    def get_user_memory_summary(self, user_id: str) -> Dict:
        """Get summary statistics about user's memories"""
        with self.pg_conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM user_memory_summary
                WHERE user_id = %s
            """, (user_id,))

            result = cur.fetchone()

            if not result:
                return {
                    'user_id': user_id,
                    'total_facts': 0,
                    'fact_types': 0,
                    'avg_confidence': 0.0,
                    'last_updated': None
                }

            return dict(result)

    def create_graph_nodes_and_relationships(
        self,
        fact_id: str,
        entities: List[Dict],
        relationships: List[Dict]
    ):
        """
        Create graph nodes and relationships using Apache AGE
        Example entities: [{'type': 'Person', 'name': 'John', 'properties': {...}}]
        Example relationships: [{'type': 'MENTIONS', 'from': 'fact_id', 'to': 'person_id'}]
        """
        with self.pg_conn.cursor() as cur:
            # Load AGE extension
            cur.execute("LOAD 'age';")
            cur.execute("SET search_path = ag_catalog, '$user', public;")

            # Create nodes for entities
            for entity in entities:
                entity_type = entity['type']
                properties = entity.get('properties', {})
                properties['fact_id'] = fact_id

                # Convert properties to AGE format
                props_str = ', '.join(
                    f"{k}: '{v}'" for k, v in properties.items()
                )

                cypher_query = f"""
                    SELECT * FROM cypher('memory_graph', $$
                        CREATE (n:{entity_type} {{{props_str}}})
                        RETURN n
                    $$) as (n agtype);
                """
                cur.execute(cypher_query)

            # Create relationships
            for rel in relationships:
                rel_type = rel['type']
                from_id = rel['from']
                to_id = rel['to']

                cypher_query = f"""
                    SELECT * FROM cypher('memory_graph', $$
                        MATCH (a {{id: '{from_id}'}}), (b {{id: '{to_id}'}})
                        CREATE (a)-[r:{rel_type}]->(b)
                        RETURN r
                    $$) as (r agtype);
                """
                cur.execute(cypher_query)

            self.pg_conn.commit()

    def query_graph(self, cypher_query: str) -> List[Dict]:
        """
        Execute a Cypher query on the knowledge graph
        Returns results as list of dictionaries
        """
        with self.pg_conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("LOAD 'age';")
            cur.execute("SET search_path = ag_catalog, '$user', public;")

            full_query = f"""
                SELECT * FROM cypher('memory_graph', $$
                    {cypher_query}
                $$) as (result agtype);
            """
            cur.execute(full_query)
            results = cur.fetchall()

            return [dict(row) for row in results]

    def close(self):
        """Close all connections"""
        self.pg_conn.close()
        self.redis_client.close()


# Example usage
if __name__ == "__main__":
    # Initialize service
    service = MemoryService()

    # Example workflow
    user_id = "user_123"
    session_id = "session_abc"

    # 1. Create conversation
    conversation_id = service.create_conversation(user_id, session_id)
    print(f"Created conversation: {conversation_id}")

    # 2. Add a message
    message = service.add_message(
        conversation_id,
        role="user",
        content="I love hiking in the mountains and photography"
    )
    print(f"Added message: {message['message_id']}")

    # 3. Extract and store facts
    facts = service.extract_and_store_facts(
        user_id,
        "User loves hiking and photography",
        message['message_id'],
        fact_type='preference'
    )
    print(f"Stored facts: {facts}")

    # 4. Find similar memories
    similar = service.find_similar_memories(
        "What outdoor activities does the user enjoy?",
        user_id,
        limit=5
    )
    print(f"Similar memories: {similar}")

    # 5. Get memory summary
    summary = service.get_user_memory_summary(user_id)
    print(f"Memory summary: {summary}")

    # Clean up
    service.close()
