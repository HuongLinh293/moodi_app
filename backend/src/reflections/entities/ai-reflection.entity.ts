import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

// Chỉ lưu kết quả phản tư trả cho chính người dùng, không lưu prompt gửi nhà cung cấp AI.
@Entity('ai_reflections')
@Index(['userId', 'createdAt'])
@Index(['userId', 'entryId'], { unique: true, where: '"entryId" IS NOT NULL' })
export class AiReflection {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  // id nhật ký do app sinh. Cùng user + entry chỉ giữ một phản tư.
  @Column({ type: 'varchar', length: 160, nullable: true })
  entryId: string | null;

  @Column({ type: 'varchar', length: 40 })
  emotionKey: string;

  @Column({ type: 'int' })
  intensity: number;

  @Column({ type: 'jsonb' })
  result: Record<string, unknown>;

  @Column({ type: 'varchar', length: 20 })
  source: 'ai' | 'template' | 'safety';

  @Column({ type: 'boolean', nullable: true })
  helpful: boolean | null;

  @Column({ type: 'text', nullable: true })
  feedback: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
