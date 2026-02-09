-- MeraBriar Database Schema
-- This sets up the Supabase Postgres database for the messenger

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-------------------------------------------------
-- USERS TABLE
-------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_hash TEXT UNIQUE NOT NULL,  -- SHA256 of phone for lookup
    display_name TEXT,
    avatar_url TEXT,
    
    -- Public keys (only public keys stored on server)
    identity_public_key BYTEA NOT NULL,
    signed_prekey BYTEA NOT NULL,
    signed_prekey_signature BYTEA NOT NULL,
    
    -- Status
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    is_online BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for phone lookup
CREATE INDEX IF NOT EXISTS idx_users_phone_hash ON users(phone_hash);

-------------------------------------------------
-- PREKEYS TABLE (One-time keys)
-------------------------------------------------
CREATE TABLE IF NOT EXISTS prekeys (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_id INTEGER NOT NULL,
    public_key BYTEA NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, key_id)
);

-- Index for unused prekeys
CREATE INDEX IF NOT EXISTS idx_prekeys_user_unused ON prekeys(user_id, used) WHERE used = FALSE;

-------------------------------------------------
-- MESSAGES TABLE
-------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES users(id),
    recipient_id UUID NOT NULL REFERENCES users(id),
    
    -- All content is encrypted client-side
    -- Server only sees encrypted blobs
    encrypted_content BYTEA NOT NULL,
    
    -- Message metadata (not encrypted - needed for delivery)
    message_type TEXT DEFAULT 'text',  -- text, image, voice, etc.
    
    -- Status
    status TEXT DEFAULT 'pending',  -- pending, sent, delivered, read
    
    -- Timestamps
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
);

-- Indexes for message queries
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_pending ON messages(recipient_id, status) WHERE status = 'pending';

-------------------------------------------------
-- CONTACTS TABLE
-------------------------------------------------
CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    alias TEXT,  -- User's custom name for contact
    is_verified BOOLEAN DEFAULT FALSE,  -- QR code verified
    is_blocked BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, contact_id)
);

-- Index for contact lookups
CREATE INDEX IF NOT EXISTS idx_contacts_user ON contacts(user_id);

-------------------------------------------------
-- GROUPS TABLE (Phase 2)
-------------------------------------------------
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    avatar_url TEXT,
    creator_id UUID NOT NULL REFERENCES users(id),
    
    -- Group encryption key (encrypted for each member)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-------------------------------------------------
-- GROUP MEMBERS TABLE (Phase 2)
-------------------------------------------------
CREATE TABLE IF NOT EXISTS group_members (
    id SERIAL PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    role TEXT DEFAULT 'member',  -- admin, member
    
    -- Encrypted group key for this member
    encrypted_group_key BYTEA,
    
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(group_id, user_id)
);

-------------------------------------------------
-- ROW LEVEL SECURITY (Critical!)
-------------------------------------------------

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Users: Can read any, update own
CREATE POLICY "Users can view any profile" ON users
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Prekeys: Only own prekeys
CREATE POLICY "Users can manage own prekeys" ON prekeys
    FOR ALL USING (auth.uid() = user_id);

-- Allow fetching one unused prekey for any user (for initial key exchange)
CREATE POLICY "Users can fetch unused prekey" ON prekeys
    FOR SELECT USING (used = FALSE);

-- Messages: Can access own messages (sent or received)
CREATE POLICY "Users can view own messages" ON messages
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can insert messages" ON messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Recipient can update message status" ON messages
    FOR UPDATE USING (auth.uid() = recipient_id);

-- Contacts: Only own contacts
CREATE POLICY "Users can manage own contacts" ON contacts
    FOR ALL USING (auth.uid() = user_id);

-- Groups: Members can view
CREATE POLICY "Group members can view group" ON groups
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_members.group_id = groups.id 
            AND group_members.user_id = auth.uid()
        )
    );

CREATE POLICY "Creator can update group" ON groups
    FOR UPDATE USING (auth.uid() = creator_id);

CREATE POLICY "Users can create groups" ON groups
    FOR INSERT WITH CHECK (auth.uid() = creator_id);

-- Group members: Members can view membership
CREATE POLICY "Members can view group members" ON group_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = group_members.group_id 
            AND gm.user_id = auth.uid()
        )
    );

-------------------------------------------------
-- FUNCTIONS
-------------------------------------------------

-- Update user's online status
CREATE OR REPLACE FUNCTION update_user_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_status_trigger
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_user_status();

-- Get unused prekey and mark as used
CREATE OR REPLACE FUNCTION get_and_mark_prekey(target_user_id UUID)
RETURNS TABLE (key_id INTEGER, public_key BYTEA) AS $$
BEGIN
    RETURN QUERY
    UPDATE prekeys
    SET used = TRUE
    WHERE id = (
        SELECT id FROM prekeys 
        WHERE user_id = target_user_id AND used = FALSE 
        LIMIT 1
    )
    RETURNING prekeys.key_id, prekeys.public_key;
END;
$$ LANGUAGE plpgsql;

-- Update message status to delivered
CREATE OR REPLACE FUNCTION mark_message_delivered(message_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE messages
    SET status = 'delivered', delivered_at = NOW()
    WHERE id = message_id AND status = 'pending';
END;
$$ LANGUAGE plpgsql;

-- Update message status to read
CREATE OR REPLACE FUNCTION mark_message_read(message_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE messages
    SET status = 'read', read_at = NOW()
    WHERE id = message_id AND (status = 'pending' OR status = 'delivered');
END;
$$ LANGUAGE plpgsql;

-------------------------------------------------
-- REALTIME SUBSCRIPTIONS
-------------------------------------------------

-- Enable realtime for messages (new messages and status updates)
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- Enable realtime for user status (online/offline)
ALTER PUBLICATION supabase_realtime ADD TABLE users;
