-- Zmiana nazwy tabeli, aby pasowała do encji PartUsage (@Table(name="part_usages"))
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'part_usage')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'part_usages') THEN
    EXECUTE 'ALTER TABLE part_usage RENAME TO part_usages';
  END IF;
END $$;

-- Idempotentne indeksy (FK zostaną zachowane przy RENAME)
CREATE INDEX IF NOT EXISTS idx_part_usages_raport_id ON part_usages(raport_id);
CREATE INDEX IF NOT EXISTS idx_part_usages_part_id   ON part_usages(part_id);