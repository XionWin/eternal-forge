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
(1, 'Web', 'Collected from website'),
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

CREATE OR REPLACE FUNCTION trgfn_note_categories_auto_set_default_category()
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

DROP TRIGGER IF EXISTS trg_note_categories_auto_set_default_category_on_insert ON note_categories;
CREATE TRIGGER trg_note_categories_auto_set_default_category_on_insert
BEFORE INSERT ON note_categories
FOR EACH ROW
EXECUTE FUNCTION trgfn_note_categories_auto_set_default_category();

DROP TRIGGER IF EXISTS trg_note_categories_auto_set_default_category_on_update ON note_categories;
CREATE TRIGGER trg_note_categories_auto_set_default_category_on_update
AFTER UPDATE OF is_default, user_id ON note_categories
FOR EACH ROW
EXECUTE FUNCTION trgfn_note_categories_auto_set_default_category();

CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    content TEXT NOT NULL,
	source_type INTEGER NOT NULL REFERENCES note_source_types(id),

    category INTEGER REFERENCES note_categories(id) ON DELETE SET NULL,
	
    meta JSONB DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_notes_user_time ON notes(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category);
CREATE INDEX IF NOT EXISTS idx_notes_source_type ON notes(source_type);

CREATE OR REPLACE FUNCTION trgfn_notes_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_notes_set_updated_at_on_update ON notes;
CREATE TRIGGER trg_notes_set_updated_at_on_update
BEFORE UPDATE ON notes
FOR EACH ROW
EXECUTE FUNCTION trgfn_notes_set_updated_at();

CREATE OR REPLACE FUNCTION trgfn_notes_set_default_category()
RETURNS TRIGGER AS $$
DECLARE
  v_default_category_id INTEGER;
BEGIN
  IF NEW.category_id IS NULL THEN
    SELECT id INTO v_default_category_id
    FROM note_categories
    WHERE user_id = NEW.user_id
      AND is_default = TRUE
    LIMIT 1;

    IF FOUND THEN
      NEW.category_id := v_default_category_id;
    END IF;
    -- If current use has no any categroy, keep the NULL value.
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notes_set_default_category_on_insert ON notes;
CREATE TRIGGER trg_notes_set_default_category_on_insert
BEFORE INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION trgfn_notes_set_default_category();


CREATE OR REPLACE FUNCTION func_set_default_category(p_id UUID, p_category_id INTEGER)
RETURNS VOID AS $$
DECLARE
	v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('PA007', p_id);
    END IF;
	
	-- Check attribution
	IF NOT EXISTS (
	SELECT 1 FROM note_categories WHERE id = p_category_id AND user_id = p_id
	) THEN
	PERFORM util_raise_error('PN001', p_category_id, v_account);
	END IF;

	-- 原子切换默认
	UPDATE note_categories
	SET is_default = (id = p_category_id)
	WHERE user_id = p_id;
END;
$$ LANGUAGE plpgsql;
