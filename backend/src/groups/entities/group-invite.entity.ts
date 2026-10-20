import {
  Entity,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Column,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Group } from './group.entity';

@Entity('group_invites')
export class GroupInvite {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Group, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'groupId' })
  group: Group;

  @Column()
  groupId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipientId' })
  recipient: User;

  @Column()
  recipientId: string;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'senderId' })
  sender: User;

  @Column({ nullable: true })
  senderId: string;

  @CreateDateColumn()
  createdAt: Date;
}
