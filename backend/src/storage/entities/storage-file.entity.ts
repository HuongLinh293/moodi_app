import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('storage_files')
export class StorageFile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'uploadedById' })
  uploadedBy: User;

  @Column()
  uploadedById: string;

  @Column({ type: 'varchar', length: 255 })
  filename: string;

  @Column({ type: 'varchar', length: 500 })
  filePath: string;

  @Column({ type: 'int' })
  fileSize: number;

  @Column({ type: 'varchar', length: 50, nullable: true })
  mimeType: string;

  @Column({ type: 'enum', enum: ['public', 'private'], default: 'private' })
  accessType: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  relatedEntityType: string;

  @Column({ type: 'uuid', nullable: true })
  relatedEntityId: string;

  @CreateDateColumn()
  createdAt: Date;
}
