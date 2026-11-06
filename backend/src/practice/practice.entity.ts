import { Column, Entity, Index, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';
import { User } from '../users/entities/user.entity';

@Entity('practice_records')
@Index(['userId', 'timestamp'])
export class PracticeRecord {
  @PrimaryColumn('uuid') userId: string;
  @PrimaryColumn({ type: 'varchar', length: 160 }) id: string;
  @ManyToOne(() => User, { onDelete: 'CASCADE' }) @JoinColumn({ name: 'userId' }) user: User;
  @Column({ type: 'varchar', length: 80 }) exerciseId: string;
  @Column({ type: 'timestamptz' }) timestamp: Date;
  @Column({ type: 'varchar', length: 160, nullable: true }) sourceEntryId: string | null;
  @Column({ type: 'text', default: '' }) note: string;
  @Column({ type: 'varchar', length: 40, nullable: true }) beforeEmotionKey: string | null;
  @Column({ type: 'int', nullable: true }) beforeIntensity: number | null;
  @Column({ type: 'varchar', length: 40, nullable: true }) afterEmotionKey: string | null;
  @Column({ type: 'int', nullable: true }) afterIntensity: number | null;
  @Column({ type: 'int', nullable: true }) usefulnessRating: number | null;
  @Column({ type: 'int', nullable: true }) easeRating: number | null;
  @Column({ type: 'varchar', length: 20, nullable: true }) repeatPreference: string | null;
}
