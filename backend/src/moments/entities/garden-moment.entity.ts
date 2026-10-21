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

@Entity('garden_moments')
@Index(['userId', 'monthKey'])
export class GardenMoment {
  @PrimaryColumn('uuid')
  userId: string;

  @PrimaryColumn({ type: 'varchar', length: 160 })
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'varchar', length: 160 })
  entryId: string;

  @Column({ type: 'varchar', length: 7 })
  monthKey: string;

  @Column({ type: 'int' })
  bedIndex: number;

  @Column({ type: 'int' })
  slotIndex: number;

  @Column({ type: 'timestamptz' })
  plantedAt: Date;

  @Column({ type: 'int', default: 0 })
  appearanceVariant: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
