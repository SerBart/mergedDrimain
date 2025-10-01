-- Add email column to users and enforce uniqueness
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- Backfill email for existing rows if null
UPDATE users SET email = LOWER(username) || '@local' WHERE email IS NULL;

-- Enforce not null
ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- Add unique constraint on email
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);
