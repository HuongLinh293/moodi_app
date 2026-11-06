import { MigrationInterface, QueryRunner } from 'typeorm';
export class AddPasswordResets1794000000001 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`CREATE TABLE IF NOT EXISTS "password_resets" (
      "id" uuid PRIMARY KEY, "userId" uuid REFERENCES "users"("id") ON DELETE CASCADE,
      "codeHash" varchar(64) NOT NULL, "expiresAt" timestamptz NOT NULL, "attempts" int NOT NULL DEFAULT 0
    )`);
  }
  async down(runner: QueryRunner): Promise<void> { await runner.query('DROP TABLE IF EXISTS "password_resets"'); }
}
