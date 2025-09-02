DROP TABLE IF EXISTS note_source_types CASCADE;
DROP TABLE IF EXISTS collections CASCADE;
DROP TABLE IF EXISTS notes CASCADE;

CREATE TABLE note_source_types (
    id INTEGER PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);
INSERT INTO note_source_types (id, name, description) VALUES
(0, 'Unknown', 'Unknown source'),
(1, 'Web', 'Collected from website'),
(2, 'Manual', 'Manually added by user');

CREATE TABLE collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL,
    meta JSONB DEFAULT '{}'::jsonb,

    UNIQUE(user_id, name)
);
CREATE UNIQUE INDEX idx_collections_user_default
    ON collections(user_id)
    WHERE is_active = TRUE;

CREATE OR REPLACE FUNCTION trgfn_collections_set_active()
RETURNS TRIGGER
AS $$
BEGIN
  IF NEW.user_id IS NOT NULL AND COALESCE(NEW.is_active, FALSE) = FALSE THEN
    -- Check current user has the default collection, if not change current collection as the default one.
    IF NOT EXISTS (
      SELECT 1 FROM collections
      WHERE user_id = NEW.user_id AND is_active = TRUE
    ) THEN
      NEW.is_active := TRUE;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_collections_set_active_on_insert ON collections;
CREATE TRIGGER trg_collections_set_active_on_insert
BEFORE INSERT ON collections
FOR EACH ROW
EXECUTE FUNCTION trgfn_collections_set_active();

DROP TRIGGER IF EXISTS trg_collections_set_active_on_update ON collections;
CREATE TRIGGER trg_collections_set_active_on_update
BEFORE UPDATE OF is_active, user_id ON collections
FOR EACH ROW
EXECUTE FUNCTION trgfn_collections_set_active();

CREATE OR REPLACE FUNCTION trgfn_collections_check_before_delete()
RETURNS TRIGGER AS $$
DECLARE
    v_note_count INTEGER;
    v_account VARCHAR;
BEGIN
    IF EXISTS (SELECT 1 FROM notes WHERE collection_id = OLD.id) THEN
	    SELECT account INTO v_account
	    FROM users
	    WHERE id = OLD.user_id;
	
	    PERFORM util_raise_error('PN003', OLD.name, v_account);
	END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_collections_check_before_delete ON collections;
CREATE TRIGGER trg_collections_check_before_delete
BEFORE DELETE ON collections
FOR EACH ROW
EXECUTE FUNCTION trgfn_collections_check_before_delete();

CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    content TEXT NOT NULL,
    source_type INTEGER NOT NULL REFERENCES note_source_types(id),
    
    meta JSONB DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_notes_collection ON notes(collection_id);
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

CREATE OR REPLACE FUNCTION trgfn_notes_set_default_collection()
RETURNS TRIGGER AS $$
DECLARE
  v_default_collection_id UUID;
BEGIN
  IF NEW.collection_id IS NULL THEN
  	SELECT id INTO v_default_collection_id
	FROM collections
	WHERE user_id = NEW.user_id
	  AND is_active = TRUE
	LIMIT 1;

	IF v_default_collection_id IS NULL THEN
	    v_default_collection_id := func_get_default_collection(NEW.user_id);
	END IF;
	NEW.collection_id := v_default_collection_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notes_set_default_collection_on_insert ON notes;
CREATE TRIGGER trg_notes_set_default_collection_on_insert
BEFORE INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION trgfn_notes_set_default_collection();

-- Collections
CREATE OR REPLACE FUNCTION func_add_collection(
    p_user_id UUID,
    p_name VARCHAR,
    p_description TEXT,
    p_is_active BOOLEAN
) RETURNS UUID AS $$
DECLARE
    v_account VARCHAR;
    v_collection_id UUID;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('PA007', p_user_id);
    END IF;

    IF EXISTS (
        SELECT 1 
        FROM collections 
        WHERE user_id = p_user_id AND name = p_name
    ) THEN
        PERFORM util_raise_error('PN001', p_name, v_account);
    END IF;

    INSERT INTO collections (user_id, name, description, is_active)
    VALUES (p_user_id, p_name, p_description, p_is_active)
    RETURNING id INTO v_collection_id;

    -- If the new item should be default, we need to set the others as undefault.
    IF p_is_active THEN
        UPDATE collections
        SET is_active = FALSE
        WHERE user_id = p_user_id AND id <> v_collection_id;
    END IF;

	RETURN v_collection_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION func_change_default_collection(p_user_id UUID, p_collection_id UUID)
RETURNS VOID AS $$
DECLARE
    v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('PA007', p_user_id);
    END IF;
    
    -- Check attribution
    IF NOT EXISTS (
    SELECT 1 FROM collections WHERE id = p_collection_id AND user_id = p_user_id
    ) THEN
        PERFORM util_raise_error('PN002', p_collection_id, v_account);
    END IF;

    -- Set current as active, and others as inactive
    UPDATE collections
    SET is_active = (id = p_collection_id)
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_get_default_collection(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    v_account VARCHAR;
    v_default_collection_id UUID;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('PA007', p_user_id);
    END IF;

    SELECT id INTO v_default_collection_id
    FROM collections
    WHERE user_id = p_user_id
      AND is_active = TRUE
    LIMIT 1;

    IF v_default_collection_id IS NULL THEN
        v_default_collection_id := func_add_collection(p_user_id, 'Default', 'Default collection for user', TRUE);
    END IF;

    RETURN v_default_collection_id;
END;
$$ LANGUAGE plpgsql;


-- Notes
CREATE OR REPLACE FUNCTION func_add_note(
    p_content TEXT,
    p_collection_id UUID,
    p_source_type INTEGER,
	p_meta JSONB
) RETURNS UUID AS $$
DECLARE
    v_note_id UUID;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM note_source_types WHERE id = p_source_type
    ) THEN
        PERFORM util_raise_error('PN004', p_source_type);
    END IF;

	IF p_meta IS NULL THEN
	    INSERT INTO notes (content, source_type, collection_id)
	    VALUES (p_content, p_source_type, p_collection_id)
	    RETURNING id INTO v_note_id;
	ELSE
	    INSERT INTO notes (content, source_type, collection_id, meta)
	    VALUES (p_content, p_source_type, p_collection_id, p_meta)
	    RETURNING id INTO v_note_id;
	END IF;

    RETURN v_note_id;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION func_add_note(
    p_content TEXT,
    p_collection_id UUID,
    p_source_type INTEGER
) RETURNS UUID AS $$
DECLARE
    v_note_id UUID;
BEGIN
	v_note_id := func_add_note(p_content, p_collection_id, p_source_type, NULL);

    RETURN v_note_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_update_note_meta(
    p_note_id UUID,
    p_meta JSONB
)
RETURNS VOID
AS $$
BEGIN
    IF NOT EXISTS (
		SELECT 1
	    FROM notes
	    WHERE id = p_note_id
	) THEN
        PERFORM util_raise_error('PN005', p_note_id::text);
    END IF;

    UPDATE notes
    SET meta = p_meta
    WHERE id = p_note_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_delete_note(
    p_note_id UUID
)
RETURNS VOID
AS $$
BEGIN
    IF NOT EXISTS (
		SELECT 1 FROM notes WHERE id = p_note_id
	) THEN
        PERFORM util_raise_error('PN005', p_note_id);
    END IF;

    DELETE FROM notes
    WHERE id = p_note_id;
END;
$$ LANGUAGE plpgsql;
