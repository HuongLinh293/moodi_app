import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPracticeRecords1794000000000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`CREATE TABLE IF NOT EXISTS "practice_records" (
      "userId" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
      "id" varchar(160) NOT NULL, "exerciseId" varchar(80) NOT NULL,
      "timestamp" timestamptz NOT NULL, "sourceEntryId" varchar(160),
      "note" text NOT NULL DEFAULT '', "beforeEmotionKey" varchar(40), "beforeIntensity" int,
      "afterEmotionKey" varchar(40), "afterIntensity" int, "usefulnessRating" int,
      "easeRating" int, "repeatPreference" varchar(20), PRIMARY KEY ("userId", "id")
    )`);
    await runner.query(`CREATE INDEX IF NOT EXISTS "practice_records_user_timestamp" ON "practice_records" ("userId", "timestamp")`);
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query(`DROP TABLE IF EXISTS "practice_records"`);
  }
}
