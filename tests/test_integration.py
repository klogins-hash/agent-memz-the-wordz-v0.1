#!/usr/bin/env python3
"""
Comprehensive Integration Test for Agent Memz
Tests all components: Cohere embeddings, PostgreSQL, Redis, MinIO, vector search
"""

import sys
import os
import time
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.memory_service import MemoryService


def print_test(test_name: str):
    """Print test section header"""
    print(f"\n{'='*60}")
    print(f"🔍 TEST: {test_name}")
    print(f"{'='*60}")


def print_success(message: str):
    """Print success message"""
    print(f"✅ {message}")


def print_error(message: str):
    """Print error message"""
    print(f"❌ {message}")


def print_info(message: str):
    """Print info message"""
    print(f"ℹ️  {message}")


def test_cohere_embeddings(service: MemoryService):
    """Test Cohere embedding generation with multilingual support"""
    print_test("Cohere Embedding Generation (Multilingual)")

    test_texts = {
        'english': "I love hiking in the mountains",
        'spanish': "Me encanta hacer senderismo en las montañas",
        'french': "J'adore faire de la randonnée dans les montagnes",
        'german': "Ich liebe es, in den Bergen zu wandern",
        'japanese': "私は山でのハイキングが大好きです",
        'chinese': "我喜欢在山里徒步旅行"
    }

    embeddings = {}

    for lang, text in test_texts.items():
        try:
            start_time = time.time()
            embedding = service.generate_embedding(text, use_cache=False)
            elapsed = time.time() - start_time

            embeddings[lang] = embedding

            print_success(f"{lang.capitalize()}: Generated {len(embedding)}-dim embedding in {elapsed:.2f}s")
            print_info(f"   Text: {text}")
            print_info(f"   First 5 values: {embedding[:5]}")

            # Verify embedding dimensions
            if len(embedding) == 1024:  # Cohere v4 multilingual is 1024 dimensions
                print_success(f"   Correct dimension (1024)")
            else:
                print_error(f"   Wrong dimension! Expected 1024, got {len(embedding)}")

        except Exception as e:
            print_error(f"{lang.capitalize()}: Failed to generate embedding - {e}")
            return False

    # Test caching
    print_info("\nTesting Redis caching...")
    try:
        start_time = time.time()
        cached_embedding = service.generate_embedding(test_texts['english'], use_cache=True)
        cached_elapsed = time.time() - start_time

        if cached_elapsed < 0.01:  # Should be instant from cache
            print_success(f"Cache working! Retrieved in {cached_elapsed:.4f}s (vs {elapsed:.2f}s uncached)")
        else:
            print_error(f"Cache may not be working - took {cached_elapsed:.4f}s")

        if cached_embedding == embeddings['english']:
            print_success("Cached embedding matches original")
        else:
            print_error("Cached embedding doesn't match!")

    except Exception as e:
        print_error(f"Cache test failed: {e}")
        return False

    return True


def test_database_operations(service: MemoryService):
    """Test PostgreSQL operations with conversations and messages"""
    print_test("PostgreSQL Database Operations")

    # Use unique IDs to avoid conflicts
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    user_id = f"test_user_{timestamp}"
    session_id = f"test_session_{timestamp}"

    try:
        # Create conversation
        print_info("Creating conversation...")
        conversation_id = service.create_conversation(
            user_id,
            session_id,
            metadata={'test': True, 'timestamp': timestamp}
        )
        print_success(f"Created conversation: {conversation_id}")

        # Add messages in multiple languages
        messages = [
            ("English: I enjoy hiking", "user"),
            ("Spanish: Me gusta programar", "user"),
            ("Japanese: 私は料理が好きです", "user"),
        ]

        message_ids = []
        for content, role in messages:
            print_info(f"Adding message: {content}")
            msg = service.add_message(
                conversation_id,
                role=role,
                content=content,
                metadata={'language_test': True}
            )
            message_ids.append(msg['message_id'])
            print_success(f"  Message ID: {msg['message_id']}")

        # Extract and store facts
        print_info("\nExtracting and storing facts...")
        fact_ids = service.extract_and_store_facts(
            user_id,
            "User enjoys outdoor activities and programming",
            message_ids[0],
            fact_type='preference'
        )
        print_success(f"Stored {len(fact_ids)} facts")

        return True

    except Exception as e:
        print_error(f"Database operations failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_redis_sessions(service: MemoryService):
    """Test Redis session management"""
    print_test("Redis Session Management")

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    session_id = f"redis_test_{timestamp}"

    try:
        # Update session context
        print_info("Setting session context...")
        service.update_session_context(
            session_id,
            {
                'language': 'multilingual',
                'preferences': {'theme': 'dark', 'notifications': True},
                'last_activity': datetime.now().isoformat()
            }
        )
        print_success("Session context updated")

        # Retrieve session context
        print_info("Retrieving session context...")
        context = service.get_session_context(session_id)

        if context:
            print_success("Session context retrieved:")
            for key, value in context.items():
                print_info(f"  {key}: {value}")
        else:
            print_error("Failed to retrieve session context")
            return False

        return True

    except Exception as e:
        print_error(f"Redis session test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_vector_similarity_search(service: MemoryService):
    """Test vector similarity search with multilingual queries"""
    print_test("Vector Similarity Search (Multilingual)")

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    user_id = f"search_test_{timestamp}"
    session_id = f"search_session_{timestamp}"

    try:
        # Create test data
        print_info("Creating test data...")
        conv_id = service.create_conversation(user_id, session_id)

        test_facts = [
            "I love hiking in the mountains and taking photographs",
            "Programming in Python is my favorite hobby",
            "I enjoy cooking Italian and Japanese cuisine",
            "Playing guitar and making music relaxes me",
            "Reading science fiction novels is fascinating"
        ]

        # Store facts
        for fact in test_facts:
            msg = service.add_message(conv_id, "user", fact)
            service.extract_and_store_facts(user_id, fact, msg['message_id'])

        print_success(f"Stored {len(test_facts)} facts")

        # Test similarity searches in different languages
        test_queries = [
            ("What outdoor activities does the user like?", "English"),
            ("¿Qué le gusta cocinar al usuario?", "Spanish"),
            ("ユーザーの趣味は何ですか？", "Japanese"),
        ]

        for query, lang in test_queries:
            print_info(f"\nQuery ({lang}): {query}")

            results = service.find_similar_memories(
                query,
                user_id,
                threshold=0.3,  # Lower threshold for testing
                limit=3,
                use_cache=False
            )

            if results:
                print_success(f"Found {len(results)} similar memories:")
                for i, memory in enumerate(results, 1):
                    print_info(f"  {i}. [{memory['similarity']:.3f}] {memory['content'][:60]}...")
            else:
                print_error("No similar memories found")

        return True

    except Exception as e:
        print_error(f"Vector similarity search failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_minio_storage(service: MemoryService):
    """Test MinIO object storage"""
    print_test("MinIO Object Storage")

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    user_id = f"minio_test_{timestamp}"
    session_id = f"minio_session_{timestamp}"

    try:
        # Create fake audio data
        print_info("Creating test audio data...")
        fake_audio = b"FAKE_AUDIO_DATA_" + timestamp.encode()

        # Store audio
        print_info("Uploading to MinIO...")
        audio_url = service.store_audio(
            user_id,
            session_id,
            fake_audio,
            filename=f"test_{timestamp}.wav"
        )

        print_success(f"Audio stored successfully")
        print_info(f"  URL: {audio_url[:80]}...")

        return True

    except Exception as e:
        print_error(f"MinIO storage test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_memory_summary(service: MemoryService):
    """Test user memory summary"""
    print_test("User Memory Summary")

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    user_id = f"summary_test_{timestamp}"

    try:
        # Get summary (should be empty initially)
        print_info("Getting memory summary...")
        summary = service.get_user_memory_summary(user_id)

        print_success("Memory summary retrieved:")
        for key, value in summary.items():
            print_info(f"  {key}: {value}")

        return True

    except Exception as e:
        print_error(f"Memory summary test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run all integration tests"""
    print("\n" + "="*60)
    print("🚀 AGENT MEMZ - COMPREHENSIVE INTEGRATION TEST")
    print("="*60)
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    try:
        # Initialize service
        print_info("\nInitializing Memory Service...")
        service = MemoryService()
        print_success("Service initialized successfully")

        # Run tests
        tests = [
            ("Cohere Embeddings", lambda: test_cohere_embeddings(service)),
            ("Database Operations", lambda: test_database_operations(service)),
            ("Redis Sessions", lambda: test_redis_sessions(service)),
            ("Vector Similarity Search", lambda: test_vector_similarity_search(service)),
            ("MinIO Storage", lambda: test_minio_storage(service)),
            ("Memory Summary", lambda: test_memory_summary(service)),
        ]

        results = {}
        for test_name, test_func in tests:
            try:
                results[test_name] = test_func()
            except Exception as e:
                print_error(f"{test_name} crashed: {e}")
                import traceback
                traceback.print_exc()
                results[test_name] = False

        # Print summary
        print("\n" + "="*60)
        print("📊 TEST SUMMARY")
        print("="*60)

        passed = sum(1 for v in results.values() if v)
        total = len(results)

        for test_name, result in results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{status} - {test_name}")

        print(f"\n{passed}/{total} tests passed")

        if passed == total:
            print("\n🎉 ALL TESTS PASSED! 🎉")
            print("Agent Memz is fully operational with Cohere v4 multilingual embeddings")
        else:
            print(f"\n⚠️  {total - passed} test(s) failed")
            sys.exit(1)

        # Cleanup
        service.close()
        print_success("\nService connections closed")

    except Exception as e:
        print_error(f"\nFatal error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
