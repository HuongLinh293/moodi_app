import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

// Khoá chính (userId, id): id do client sinh nên chỉ duy nhất trong phạm vi một user.
@Entity('journal_entries')
@Index(['userId', 'timestamp'])
export class JournalEntry {
  @PrimaryColumn('uuid')
  userId: string;

  @PrimaryColumn({ type: 'varchar', length: 160 })
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'timestamptz' })
  timestamp: Date;

  @Column({ type: 'varchar', length: 40 })
  emotionKey: string;

  @Column({ type: 'int' })
  intensity: number;

  @Column({ type: 'varchar', length: 60, default: 'other' })
  trigger: string;

  @Column({ type: 'text', default: '' })
  situation: string;

  @Column({ type: 'text', default: '' })
  thought: string;

  @Column({ type: 'text', default: '' })
  response: string;

  @Column({ type: 'varchar', length: 80, nullable: true })
  exerciseId: string | null;

  @Column({ type: 'boolean', default: false })
  exerciseDone: boolean;

  @Column({ type: 'int', nullable: true })
  afterIntensity: number | null;

  @Column({ type: 'varchar', length: 40, nullable: true })
  afterEmotionKey: string | null;

  @Column({ type: 'int', nullable: true })
  usefulnessRating: number | null;

  @Column({ type: 'int', nullable: true })
  easeRating: number | null;

  @Column({ type: 'varchar', length: 40, nullable: true })
  repeatPreference: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
