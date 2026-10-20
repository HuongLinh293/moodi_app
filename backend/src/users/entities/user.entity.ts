import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToMany,
  JoinTable,
} from 'typeorm';
import { Post } from '../../posts/entities/post.entity';
import { Friend } from '../../friends/entities/friend.entity';
import { Group } from '../../groups/entities/group.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  email: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  username: string;

  @Column({ type: 'varchar', length: 255 })
  password: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  displayName: string;

  @Column({ type: 'text', nullable: true })
  bio: string;

  @Column({ type: 'varchar', length: 500, nullable: true })
  avatar: string;

  @Column({ type: 'boolean', default: false })
  isVerified: boolean;

  @Column({ type: 'varchar', nullable: true })
  refreshTokenHash?: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Relations
  @OneToMany(() => Post, (post) => post.author, { cascade: true })
  posts?: Post[];

  @OneToMany(() => Friend, (friend) => friend.user)
  friends?: Friend[];

  @ManyToMany(() => Group, (group) => group.members)
  @JoinTable({
    name: 'group_members',
    joinColumn: { name: 'userId', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'groupId', referencedColumnName: 'id' },
  })
  groups?: Group[];
}
