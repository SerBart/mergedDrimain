-- Creates or updates application user: adm / 123
-- PostgreSQL / Railway friendly
-- Password is stored as BCrypt using pgcrypto

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    v_dzial_id BIGINT;
    v_user_id BIGINT;
BEGIN
    -- Ensure required roles exist
    IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'ROLE_ADMIN') THEN
        INSERT INTO roles(name) VALUES ('ROLE_ADMIN');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'ROLE_USER') THEN
        INSERT INTO roles(name) VALUES ('ROLE_USER');
    END IF;

    -- Ensure target department exists
    SELECT id
    INTO v_dzial_id
    FROM dzialy
    WHERE lower(nazwa) = lower('Utrzymanie Ruchu')
    ORDER BY id
    LIMIT 1;

    IF v_dzial_id IS NULL THEN
        INSERT INTO dzialy(nazwa)
        VALUES ('Utrzymanie Ruchu')
        RETURNING id INTO v_dzial_id;
    END IF;

    -- Create or update user
    SELECT id
    INTO v_user_id
    FROM users
    WHERE username = 'adm'
    LIMIT 1;

    IF v_user_id IS NULL THEN
        INSERT INTO users(username, email, password, enabled, dzial_id)
        VALUES (
            'adm',
            'adm@local',
            crypt('123', gen_salt('bf', 10)),
            TRUE,
            v_dzial_id
        )
        RETURNING id INTO v_user_id;
    ELSE
        UPDATE users
        SET email = 'adm@local',
            password = crypt('123', gen_salt('bf', 10)),
            enabled = TRUE,
            dzial_id = v_dzial_id
        WHERE id = v_user_id;
    END IF;

    -- Ensure admin roles are assigned
    INSERT INTO user_roles(user_id, role_id)
    SELECT v_user_id, r.id
    FROM roles r
    WHERE r.name IN ('ROLE_ADMIN', 'ROLE_USER')
      AND NOT EXISTS (
          SELECT 1
          FROM user_roles ur
          WHERE ur.user_id = v_user_id
            AND ur.role_id = r.id
      );

    -- Ensure standard admin modules are assigned
    INSERT INTO user_modules(user_id, module)
    SELECT v_user_id, m.module
    FROM (VALUES
        ('Zgloszenia'),
        ('Raporty'),
        ('Czesci'),
        ('Instrukcje')
    ) AS m(module)
    WHERE NOT EXISTS (
        SELECT 1
        FROM user_modules um
        WHERE um.user_id = v_user_id
          AND um.module = m.module
    );
END $$;

