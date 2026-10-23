import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddNotificationData1792533200000 implements MigrationInterface {
  name = 'AddNotificationData1792533200000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "notifications" ADD COLUMN IF NOT EXISTS "data" jsonb NOT NULL DEFAULT '{}'::jsonb`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "notifications" DROP COLUMN IF EXISTS "data"`,
    );
  }
}
