import {
  Entity,
  PrimaryGeneratedColumn,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('shared_gardens')
export class SharedGarden {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // Mã mời hiện hành; xoay mỗi khi làm mới hoặc có người rời vườn.
  @Column({ type: 'varchar', length: 35, unique: true })
  code: string;

  @Column({ type: 'varchar', length: 80 })
  name: string;

  // Vị trí kế tiếp để trồng (bedIndex = slot / 20, slotIndex = slot % 20).
  @Column({ type: 'int', default: 0 })
  nextSlot: number;

  @CreateDateColumn()
  createdAt: Date;

  @OneToMany(() => SharedGardenMember, (member) => member.garden)
  members: SharedGardenMember[];
}

@Entity('shared_garden_members')
export class SharedGardenMember {
  @PrimaryColumn('uuid')
  gardenId: string;

  // Mỗi user chỉ thuộc một vườn chung tại một thời điểm.
  @PrimaryColumn('uuid')
  @Index({ unique: true })
  userId: string;

  @ManyToOne(() => SharedGarden, (garden) => garden.members, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'gardenId' })
  garden: SharedGarden;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'varchar', length: 80 })
  displayName: string;

  @CreateDateColumn()
  joinedAt: Date;
}

@Entity('shared_moments')
export class SharedMoment {
  @PrimaryColumn('uuid')
  gardenId: string;

  // `${authorId}_${entryId}`: trồng lại cùng ghi chép trả về bông đã có.
  @PrimaryColumn({ type: 'varchar', length: 200 })
  id: string;

  @ManyToOne(() => SharedGarden, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'gardenId' })
  garden: SharedGarden;

  @Column('uuid')
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'authorId' })
  author: User;

  @Column({ type: 'varchar', length: 80 })
  authorName: string;

  @Column({ type: 'varchar', length: 160 })
  entryId: string;

  @Column({ type: 'varchar', length: 40 })
  emotionKey: string;

  @Column({ type: 'int' })
  intensity: number;

  @Column({ type: 'text', default: '' })
  caption: string;

  @Column({ type: 'int' })
  bedIndex: number;

  @Column({ type: 'int' })
  slotIndex: number;

  @Column({ type: 'varchar', length: 7 })
  monthKey: string;

  @Column({ type: 'timestamptz' })
  plantedAt: Date;

  @Column({ type: 'int', default: 0 })
  waterCount: number;

  @Column({ type: 'int', default: 0 })
  sunCount: number;

  @Column({ type: 'varchar', length: 200, nullable: true })
  lastInteraction: string | null;
}

// Biên nhận chăm sóc: mỗi thành viên tưới/sưởi một bông tối đa một lần.
@Entity('shared_moment_care')
export class SharedMomentCare {
  @PrimaryColumn('uuid')
  gardenId: string;

  @PrimaryColumn({ type: 'varchar', length: 200 })
  momentId: string;

  @PrimaryColumn('uuid')
  userId: string;

  @ManyToOne(() => SharedGarden, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'gardenId' })
  garden: SharedGarden;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'boolean', default: false })
  water: boolean;

  @Column({ type: 'boolean', default: false })
  sun: boolean;
}
