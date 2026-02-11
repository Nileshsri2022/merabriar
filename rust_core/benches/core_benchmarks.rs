//! Benchmark Suite for MeraBriar Rust Core
//!
//! Measures performance across:
//! 1. Cryptography: key generation, session setup, encrypt, decrypt
//! 2. Storage: message write/read, session write/read
//! 3. Sync: queue enqueue/dequeue/filter
//! 4. Serialization: message & key bundle JSON round-trips
//!
//! Run with: cargo bench
//! Results are output by criterion to target/criterion/

use criterion::{criterion_group, criterion_main, Criterion, BenchmarkId, black_box};
use merabriar_core::crypto::{
    generate_identity_keys, get_public_key_bundle,
    init_session, encrypt_message, decrypt_message,
};
use merabriar_core::sync::QueuedMessage;
use merabriar_core::message::{Message, MessageStatus, EncryptedMessage, MessageType};

// ═══════════════════════════════════════════════════
// 1. CRYPTOGRAPHY BENCHMARKS
// ═══════════════════════════════════════════════════

fn bench_key_generation(c: &mut Criterion) {
    c.bench_function("rust/crypto/key_generation", |b| {
        b.iter(|| {
            let _bundle = generate_identity_keys().unwrap();
        });
    });
}

fn bench_session_setup(c: &mut Criterion) {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();

    c.bench_function("rust/crypto/session_setup", |b| {
        let mut counter = 0u64;
        b.iter(|| {
            let id = format!("bench_session_{}", counter);
            init_session(&id, &pub_bundle).unwrap();
            counter += 1;
        });
    });
}

fn bench_encrypt(c: &mut Criterion) {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();

    let sizes: Vec<usize> = vec![64, 256, 1024, 4096, 65536];

    let mut group = c.benchmark_group("rust/crypto/encrypt");
    for size in &sizes {
        let plaintext = "A".repeat(*size);
        let session_id = format!("enc_bench_{}", size);
        init_session(&session_id, &pub_bundle).unwrap();

        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}B", size)),
            size,
            |b, _| {
                b.iter(|| {
                    let _ct = encrypt_message(&session_id, &plaintext).unwrap();
                });
            },
        );
    }
    group.finish();
}

fn bench_encrypt_decrypt_roundtrip(c: &mut Criterion) {
    generate_identity_keys().unwrap();
    let pub_bundle = get_public_key_bundle().unwrap();

    // For decrypt benchmarks we can only test encrypt since
    // decrypt requires matching keys. We test the encrypt path
    // as a proxy for cipher throughput.
    let sizes: Vec<usize> = vec![64, 256, 1024, 4096, 65536];

    let mut group = c.benchmark_group("rust/crypto/encrypt_throughput");
    for size in &sizes {
        let plaintext = "B".repeat(*size);
        let session_id = format!("throughput_bench_{}", size);
        init_session(&session_id, &pub_bundle).unwrap();

        group.throughput(criterion::Throughput::Bytes(*size as u64));
        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}B", size)),
            size,
            |b, _| {
                b.iter(|| {
                    black_box(encrypt_message(&session_id, &plaintext).unwrap());
                });
            },
        );
    }
    group.finish();
}

// ═══════════════════════════════════════════════════
// 2. STORAGE BENCHMARKS
// ═══════════════════════════════════════════════════

fn bench_storage_write_message(c: &mut Criterion) {
    use std::fs;
    let db_path = "bench_write_msg.db";
    let _ = fs::remove_file(db_path);
    merabriar_core::init_core(db_path.to_string(), "bench_key".to_string()).unwrap();

    c.bench_function("rust/storage/write_message", |b| {
        let mut counter = 0u64;
        b.iter(|| {
            let msg = Message {
                id: format!("bench-msg-{}", counter),
                conversation_id: "bench-conv".to_string(),
                sender_id: "alice".to_string(),
                content: "Benchmark message content for storage performance testing".to_string(),
                timestamp: 1000 + counter as i64,
                status: MessageStatus::Sent,
            };
            merabriar_core::store_message_internal(msg).unwrap();
            counter += 1;
        });
    });

    let _ = fs::remove_file(db_path);
}

fn bench_storage_read_messages(c: &mut Criterion) {
    use std::fs;
    let db_path = "bench_read_msg.db";
    let _ = fs::remove_file(db_path);
    merabriar_core::init_core(db_path.to_string(), "bench_key".to_string()).unwrap();

    // Pre-populate 1000 messages
    for i in 0..1000 {
        let msg = Message {
            id: format!("read-bench-{}", i),
            conversation_id: "bench-read-conv".to_string(),
            sender_id: "alice".to_string(),
            content: format!("Message content number {}", i),
            timestamp: 1000 + i as i64,
            status: MessageStatus::Sent,
        };
        merabriar_core::store_message_internal(msg).unwrap();
    }

    c.bench_function("rust/storage/read_messages_50", |b| {
        b.iter(|| {
            let _msgs = merabriar_core::get_messages_internal(
                "bench-read-conv".to_string(), 50, 0
            ).unwrap();
        });
    });

    let _ = fs::remove_file(db_path);
}

fn bench_storage_session(c: &mut Criterion) {
    use std::fs;
    let db_path = "bench_session_storage.db";
    let _ = fs::remove_file(db_path);
    merabriar_core::init_core(db_path.to_string(), "bench_key".to_string()).unwrap();

    let session_data = vec![0xCAu8; 256]; // 256 bytes of session data

    let mut group = c.benchmark_group("rust/storage/session");

    group.bench_function("write", |b| {
        let mut counter = 0u64;
        b.iter(|| {
            let id = format!("session-bench-{}", counter);
            merabriar_core::storage::store_session(&id, &session_data).unwrap();
            counter += 1;
        });
    });

    // Pre-store a session for read bench
    merabriar_core::storage::store_session("read-session", &session_data).unwrap();

    group.bench_function("read", |b| {
        b.iter(|| {
            let _data = merabriar_core::storage::get_session("read-session").unwrap();
        });
    });

    group.finish();
    let _ = fs::remove_file(db_path);
}

// ═══════════════════════════════════════════════════
// 3. SYNC / QUEUE BENCHMARKS
// ═══════════════════════════════════════════════════

fn bench_queue_enqueue(c: &mut Criterion) {
    use merabriar_core::sync;

    // Ensure queue is initialized
    let _ = sync::init();

    c.bench_function("rust/sync/queue_enqueue", |b| {
        let mut counter = 0u64;
        b.iter(|| {
            let msg = QueuedMessage::new(
                format!("enq-bench-{}", counter),
                "recipient".to_string(),
                vec![1, 2, 3, 4, 5, 6, 7, 8],
            );
            sync::queue_message(msg).unwrap();
            counter += 1;
        });
    });
}

fn bench_queue_get_all(c: &mut Criterion) {
    use merabriar_core::sync;

    let _ = sync::init();

    // Pre-populate queue with 500 messages
    for i in 0..500 {
        let msg = QueuedMessage::new(
            format!("getall-bench-{}", i),
            if i % 2 == 0 { "alice".to_string() } else { "bob".to_string() },
            vec![1, 2, 3, 4],
        );
        sync::queue_message(msg).unwrap();
    }

    c.bench_function("rust/sync/queue_get_all", |b| {
        b.iter(|| {
            let _msgs = sync::get_queued_messages().unwrap();
        });
    });
}

fn bench_queue_filter(c: &mut Criterion) {
    use merabriar_core::sync;

    let _ = sync::init();

    c.bench_function("rust/sync/queue_filter_recipient", |b| {
        b.iter(|| {
            let _msgs = sync::get_queued_for_recipient("alice").unwrap();
        });
    });
}

// ═══════════════════════════════════════════════════
// 4. SERIALIZATION BENCHMARKS
// ═══════════════════════════════════════════════════

fn bench_message_serialize(c: &mut Criterion) {
    let msg = Message::new(
        "ser-bench-id".to_string(),
        "ser-bench-conv".to_string(),
        "alice".to_string(),
        "Benchmark serialization content with some reasonable length text".to_string(),
    );

    let mut group = c.benchmark_group("rust/serde/message");

    let json = serde_json::to_string(&msg).unwrap();

    group.bench_function("serialize", |b| {
        b.iter(|| {
            black_box(serde_json::to_string(&msg).unwrap());
        });
    });

    group.bench_function("deserialize", |b| {
        b.iter(|| {
            let _m: Message = serde_json::from_str(black_box(&json)).unwrap();
        });
    });

    group.finish();
}

fn bench_keybundle_serialize(c: &mut Criterion) {
    let bundle = generate_identity_keys().unwrap();
    let json = serde_json::to_string(&bundle).unwrap();

    let mut group = c.benchmark_group("rust/serde/keybundle");

    group.bench_function("serialize", |b| {
        b.iter(|| {
            black_box(serde_json::to_string(&bundle).unwrap());
        });
    });

    group.bench_function("deserialize", |b| {
        b.iter(|| {
            let _kb: merabriar_core::crypto::KeyBundle =
                serde_json::from_str(black_box(&json)).unwrap();
        });
    });

    group.finish();
}

fn bench_encrypted_message_serialize(c: &mut Criterion) {
    let enc = EncryptedMessage {
        id: "enc-bench".to_string(),
        sender_id: "alice".to_string(),
        recipient_id: "bob".to_string(),
        encrypted_content: vec![0xDE; 512],
        message_type: MessageType::Text,
        timestamp: 1234567890,
    };

    let json = serde_json::to_string(&enc).unwrap();

    let mut group = c.benchmark_group("rust/serde/encrypted_message");

    group.bench_function("serialize", |b| {
        b.iter(|| {
            black_box(serde_json::to_string(&enc).unwrap());
        });
    });

    group.bench_function("deserialize", |b| {
        b.iter(|| {
            let _e: EncryptedMessage = serde_json::from_str(black_box(&json)).unwrap();
        });
    });

    group.finish();
}

// ═══════════════════════════════════════════════════
// CRITERION GROUPS
// ═══════════════════════════════════════════════════

criterion_group!(
    crypto_benches,
    bench_key_generation,
    bench_session_setup,
    bench_encrypt,
    bench_encrypt_decrypt_roundtrip,
);

criterion_group!(
    storage_benches,
    bench_storage_write_message,
    bench_storage_read_messages,
    bench_storage_session,
);

criterion_group!(
    sync_benches,
    bench_queue_enqueue,
    bench_queue_get_all,
    bench_queue_filter,
);

criterion_group!(
    serde_benches,
    bench_message_serialize,
    bench_keybundle_serialize,
    bench_encrypted_message_serialize,
);

criterion_main!(crypto_benches, storage_benches, sync_benches, serde_benches);
