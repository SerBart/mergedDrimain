-- Ensure users.dzial_id exists and has FK to dzialy(id)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'dzial_id'
    ) THEN
        ALTER TABLE users ADD COLUMN dzial_id BIGINT;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'users' AND constraint_name = 'fk_users_dzial'
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT fk_users_dzial
            FOREIGN KEY (dzial_id) REFERENCES dzialy(id);
    END IF;
END $$;

-- Create user_modules table used by @ElementCollection in User entity
CREATE TABLE IF NOT EXISTS user_modules (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    module  VARCHAR(255) NOT NULL,
    PRIMARY KEY (user_id, module)
);

