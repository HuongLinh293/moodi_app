import { MigrationInterface, QueryRunner } from 'typeorm';
export class LinkReflectionEntries1794000000002 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    // Remove derivatives whose owning journal has already been deleted.
    await runner.query(`DELETE FROM "ai_reflections" r WHERE r."entryId" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM "journal_entries" e WHERE e."userId" = r."userId" AND e."id" = r."entryId")`);
    await runner.query(`DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'reflection_entry_owner_fk') THEN
        ALTER TABLE "ai_reflections" ADD CONSTRAINT "reflection_entry_owner_fk" FOREIGN KEY ("userId", "entryId") REFERENCES "journal_entries" ("userId", "id") ON DELETE CASCADE;
      END IF;
    END $$`);
  }
  async down(runner: QueryRunner): Promise<void> { await runner.query('ALTER TABLE "ai_reflections" DROP CONSTRAINT IF EXISTS "reflection_entry_owner_fk"'); }
}
