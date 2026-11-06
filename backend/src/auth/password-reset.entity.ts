import { Column, Entity, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';
import { User } from '../users/entities/user.entity';

@Entity('password_resets')
export class PasswordReset {
  @PrimaryColumn('uuid') id: string;
  @Column({ type: 'uuid', nullable: true }) userId: string | null;
  @ManyToOne(() => User, { onDelete: 'CASCADE', nullable: true }) @JoinColumn({ name: 'userId' }) user: User;
  @Column({ type: 'varchar', length: 64 }) codeHash: string;
  @Column({ type: 'timestamptz' }) expiresAt: Date;
  @Column({ type: 'int', default: 0 }) attempts: number;
}
