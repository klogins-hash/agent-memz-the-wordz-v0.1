-- Agent Memz Database Initialization Script
-- This script sets up the memory backend for the voice agent

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- CONVERSATIONS TABLE
-- Stores conversation sessions
-- ============================================================
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    session_id VARCHAR(255) UNIQUE NOT NULL,
    started_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_conversations_user_id ON conversations(user_id);
CREATE INDEX idx_conversations_session_id ON conversations(session_id);
CREATE INDEX idx_conversations_started_at ON conversations(started_at DESC);

-- ============================================================
-- MESSAGES TABLE
-- Stores individual messages in conversations
-- ============================================================
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL, -- 'user', 'assistant', 'system'
    content TEXT NOT NULL,
    audio_url VARCHAR(500), -- MinIO URL for audio
    transcription_url VARCHAR(500), -- MinIO URL for transcription
    embedding vector(1536), -- OpenAI ada-002 is 1536 dimensions
    tokens_used INTEGER DEFAULT 0,
    latency_ms INTEGER,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX idx_messages_role ON messages(role);

-- Vector similarity search index (HNSW - Hierarchical Navigable Small World)
CREATE INDEX idx_messages_embedding ON messages USING hnsw (embedding vector_cosine_ops);

-- ============================================================
-- MEMORY_FACTS TABLE
-- Stores extracted facts and knowledge from conversations
-- Uses pgvector for semantic similarity search
-- ============================================================
CREATE TABLE IF NOT EXISTS memory_facts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    fact_type VARCHAR(100) NOT NULL, -- 'preference', 'personal_info', 'context', 'instruction', etc.
    content TEXT NOT NULL,
    embedding vector(1536),
    confidence_score FLOAT DEFAULT 1.0,
    source_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    valid_from TIMESTAMP DEFAULT NOW(),
    valid_until TIMESTAMP,
    access_count INTEGER DEFAULT 0,
    last_accessed TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_memory_facts_user_id ON memory_facts(user_id);
CREATE INDEX idx_memory_facts_type ON memory_facts(fact_type);
CREATE INDEX idx_memory_facts_valid ON memory_facts(valid_from, valid_until);
CREATE INDEX idx_memory_facts_embedding ON memory_facts USING hnsw (embedding vector_cosine_ops);

-- ============================================================
-- VOICE_PROFILES TABLE
-- Stores voice characteristics and audio profiles
-- ============================================================
CREATE TABLE IF NOT EXISTS voice_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL UNIQUE,
    profile_name VARCHAR(255),
    voice_sample_urls TEXT[], -- Array of MinIO URLs
    voice_embedding vector(512), -- Voice characteristic embedding
    preferred_voice_model VARCHAR(100),
    speech_rate FLOAT DEFAULT 1.0,
    pitch_adjustment FLOAT DEFAULT 0.0,
    energy_level VARCHAR(50) DEFAULT 'medium',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_voice_profiles_user_id ON voice_profiles(user_id);
CREATE INDEX idx_voice_profiles_voice_embedding ON voice_profiles USING hnsw (voice_embedding vector_cosine_ops);

-- ============================================================
-- SEMANTIC_CLUSTERS TABLE
-- Groups related memories and facts using graph relationships
-- (Will be enhanced with Apache AGE)
-- ============================================================
CREATE TABLE IF NOT EXISTS semantic_clusters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_name VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    centroid_embedding vector(1536),
    topic_keywords TEXT[],
    memory_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_semantic_clusters_user_id ON semantic_clusters(user_id);
CREATE INDEX idx_semantic_clusters_centroid ON semantic_clusters USING hnsw (centroid_embedding vector_cosine_ops);

-- ============================================================
-- CLUSTER_MEMBERSHIPS TABLE
-- Many-to-many relationship between facts and clusters
-- ============================================================
CREATE TABLE IF NOT EXISTS cluster_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fact_id UUID NOT NULL REFERENCES memory_facts(id) ON DELETE CASCADE,
    cluster_id UUID NOT NULL REFERENCES semantic_clusters(id) ON DELETE CASCADE,
    similarity_score FLOAT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(fact_id, cluster_id)
);

CREATE INDEX idx_cluster_memberships_fact_id ON cluster_memberships(fact_id);
CREATE INDEX idx_cluster_memberships_cluster_id ON cluster_memberships(cluster_id);

-- ============================================================
-- INTERACTION_ANALYTICS TABLE
-- Tracks usage patterns and performance metrics
-- ============================================================
CREATE TABLE IF NOT EXISTS interaction_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- 'query', 'retrieval', 'storage', 'error'
    event_data JSONB NOT NULL,
    latency_ms INTEGER,
    success BOOLEAN DEFAULT true,
    timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_interaction_analytics_user_id ON interaction_analytics(user_id);
CREATE INDEX idx_interaction_analytics_event_type ON interaction_analytics(event_type);
CREATE INDEX idx_interaction_analytics_timestamp ON interaction_analytics(timestamp DESC);

-- ============================================================
-- FUNCTIONS FOR SIMILARITY SEARCH
-- ============================================================

-- Find similar messages by embedding
CREATE OR REPLACE FUNCTION find_similar_messages(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    conversation_id UUID,
    content TEXT,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.conversation_id,
        m.content,
        1 - (m.embedding <=> query_embedding) as similarity
    FROM messages m
    WHERE m.embedding IS NOT NULL
        AND 1 - (m.embedding <=> query_embedding) > match_threshold
    ORDER BY m.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Find similar memory facts
CREATE OR REPLACE FUNCTION find_similar_facts(
    query_embedding vector(1536),
    target_user_id VARCHAR(255),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    fact_type VARCHAR(100),
    similarity float,
    confidence_score float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        mf.id,
        mf.content,
        mf.fact_type,
        1 - (mf.embedding <=> query_embedding) as similarity,
        mf.confidence_score
    FROM memory_facts mf
    WHERE mf.user_id = target_user_id
        AND mf.embedding IS NOT NULL
        AND (mf.valid_until IS NULL OR mf.valid_until > NOW())
        AND 1 - (mf.embedding <=> query_embedding) > match_threshold
    ORDER BY mf.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Update memory fact access tracking
CREATE OR REPLACE FUNCTION update_fact_access(fact_id UUID)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE memory_facts
    SET
        access_count = access_count + 1,
        last_accessed = NOW()
    WHERE id = fact_id;
END;
$$;

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
CREATE TRIGGER update_conversations_updated_at BEFORE UPDATE ON conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_memory_facts_updated_at BEFORE UPDATE ON memory_facts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_voice_profiles_updated_at BEFORE UPDATE ON voice_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_semantic_clusters_updated_at BEFORE UPDATE ON semantic_clusters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- INITIAL VIEWS FOR COMMON QUERIES
-- ============================================================

-- Recent conversations with message count
CREATE OR REPLACE VIEW recent_conversations AS
SELECT
    c.id,
    c.user_id,
    c.session_id,
    c.started_at,
    c.ended_at,
    COUNT(m.id) as message_count,
    c.metadata
FROM conversations c
LEFT JOIN messages m ON m.conversation_id = c.id
GROUP BY c.id, c.user_id, c.session_id, c.started_at, c.ended_at, c.metadata
ORDER BY c.started_at DESC;

-- User memory summary
CREATE OR REPLACE VIEW user_memory_summary AS
SELECT
    user_id,
    COUNT(*) as total_facts,
    COUNT(DISTINCT fact_type) as fact_types,
    AVG(confidence_score) as avg_confidence,
    MAX(created_at) as last_updated
FROM memory_facts
WHERE valid_until IS NULL OR valid_until > NOW()
GROUP BY user_id;

-- Grant permissions (adjust as needed for your security requirements)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO agentmemz;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO agentmemz;

-- Completion message
DO $$
BEGIN
    RAISE NOTICE 'Database initialization completed successfully!';
    RAISE NOTICE 'pgvector extension enabled for semantic search';
    RAISE NOTICE 'All tables, indexes, and functions created';
END $$;
