DROP TABLE IF EXISTS note_source_types CASCADE;
DROP TABLE IF EXISTS note_categories CASCADE;
DROP TABLE IF EXISTS notes CASCADE;

CREATE TABLE note_source_types (
    id INTEGER PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);
INSERT INTO note_source_types (id, name, description) VALUES
(0, 'Unknown', 'Unknown source'),
(1, 'Web', 'Collected from browser extension or website'),
(2, 'Manual', 'Manually entered by user');

CREATE TABLE note_categories (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    UNIQUE(user_id, name)
);
CREATE UNIQUE INDEX idx_note_categories_user_default
    ON note_categories(user_id)
    WHERE is_default = TRUE;

CREATE OR REPLACE FUNCTION trgfn_note_categories_autodefault()
RETURNS TRIGGER
AS $$
BEGIN
  IF NEW.user_id IS NOT NULL AND COALESCE(NEW.is_default, FALSE) = FALSE THEN
    -- Check current user has the default category, if not change current category as the default one.
    IF NOT EXISTS (
      SELECT 1 FROM note_categories
      WHERE user_id = NEW.user_id AND is_default = TRUE
    ) THEN
      NEW.is_default := TRUE;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_note_categories_autodefault_insert ON note_categories;
CREATE TRIGGER trg_note_categories_autodefault_insert
BEFORE INSERT ON note_categories
FOR EACH ROW
EXECUTE FUNCTION trgfn_note_categories_autodefault();

DROP TRIGGER IF EXISTS trg_note_categories_single_default_update ON note_categories;
CREATE TRIGGER trg_note_categories_single_default_update
AFTER UPDATE OF is_default, user_id ON note_categories
FOR EACH ROW
EXECUTE FUNCTION trgfn_note_categories_autodefault();

CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    content TEXT NOT NULL,
    translated_content TEXT,
    language VARCHAR(16),
	source_type INTEGER NOT NULL,
    source TEXT,

    category INTEGER,
    meta JSONB DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);