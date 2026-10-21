import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { Post } from '../../posts/entities/post.entity';
import { Friend } from '../../friends/entities/friend.entity';

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
  refreshTokenHash?: string | null;

  // Tăng khi đăng xuất để mọi access token cũ hết hiệu lực ngay.
  @Column({ type: 'int', default: 0 })
  tokenVersion: number;

  @Column({ type: 'varchar', length: 255, nullable: true, unique: true })
  googleSub?: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true, unique: true })
  appleSub?: string | null;

  // Quyền kiểm duyệt Cộng đồng; chỉ cấp thủ công trong DB.
  @Column({ type: 'boolean', default: false })
  communityAdmin: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Relations
  @OneToMany(() => Post, (post) => post.author, { cascade: true })
  posts?: Post[];

  @OneToMany(() => Friend, (friend) => friend.user)
  friends?: Friend[];
}
