import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { databaseConfig } from '../../config/database.config';
import { User } from '../../users/entities/user.entity';
import { Post } from '../../posts/entities/post.entity';
import { Group } from '../../groups/entities/group.entity';
import { GroupMember } from '../../groups/entities/group-member.entity';
import { Friend } from '../../friends/entities/friend.entity';

async function seed() {
  const dataSource = new DataSource({
    ...databaseConfig(),
    logging: true,
  } as any);

  await dataSource.initialize();
  console.log('✅ Database connected');

  try {
    // Clear existing data
    console.log('🗑️  Clearing existing data...');
    await dataSource.manager.clear(Post);
    await dataSource.manager.clear(Friend);
    await dataSource.manager.clear(GroupMember);
    await dataSource.manager.clear(Group);
    await dataSource.manager.clear(User);

    // Create test users
    console.log('👥 Creating test users...');
    const userRepository = dataSource.getRepository(User);

    const users = await userRepository.save([
      {
        email: 'alice@moodi.com',
        username: 'alice',
        displayName: 'Alice Wonder',
        password: await bcrypt.hash('password123', 10),
        bio: 'Chia sẻ những khoảnh khắc tốt đẹp',
        isVerified: true,
      },
      {
        email: 'bob@moodi.com',
        username: 'bob',
        displayName: 'Bob Builder',
        password: await bcrypt.hash('password123', 10),
        bio: 'Đam mê thể dục và sức khỏe',
        isVerified: true,
      },
      {
        email: 'charlie@moodi.com',
        username: 'charlie',
        displayName: 'Charlie Chocolate',
        password: await bcrypt.hash('password123', 10),
        bio: 'Yêu nấu ăn và du lịch',
        isVerified: true,
      },
      {
        email: 'diana@moodi.com',
        username: 'diana',
        displayName: 'Diana Princess',
        password: await bcrypt.hash('password123', 10),
        bio: 'Nghệ sĩ tự do',
        isVerified: true,
      },
    ]);

    console.log(`✅ Created ${users.length} users`);

    // Create test posts
    console.log('📝 Creating test posts...');
    const postRepository = dataSource.getRepository(Post);

    const posts = await postRepository.save([
      {
        author: users[0],
        content: 'Hôm nay thời tiết thật đẹp! 🌞',
        createdAt: new Date(),
      },
      {
        author: users[0],
        content: 'Vừa hoàn thành bài tập yoga sáng. Cảm thấy sảng khoái quá!',
        createdAt: new Date(),
      },
      {
        author: users[1],
        content: 'Chạy bộ 10km hôm nay. Đạt kỷ lục cá nhân! 💪',
        createdAt: new Date(),
      },
      {
        author: users[2],
        content: 'Nấu phở chiều nay. Chúng ta cảm thấy điều nào là đặc biệt khi nấu ăn?',
        createdAt: new Date(),
      },
      {
        author: users[3],
        content: 'Vừa hoàn thành bức tranh mới. Mong các bạn thích! 🎨',
        createdAt: new Date(),
      },
    ]);

    console.log(`✅ Created ${posts.length} posts`);

    // Create friendships
    console.log('🤝 Creating friendships...');
    const friendRepository = dataSource.getRepository(Friend);

    const friendships = await friendRepository.save([
      {
        user: users[0],
        friend: users[1],
        status: 'accepted',
      },
      {
        user: users[1],
        friend: users[0],
        status: 'accepted',
      },
      {
        user: users[0],
        friend: users[2],
        status: 'accepted',
      },
      {
        user: users[2],
        friend: users[0],
        status: 'accepted',
      },
      {
        user: users[1],
        friend: users[3],
        status: 'accepted',
      },
      {
        user: users[3],
        friend: users[1],
        status: 'accepted',
      },
    ]);

    console.log(`✅ Created ${friendships.length} friendships`);

    // Create test groups
    console.log('👨‍👩‍👧‍👦 Creating test groups...');
    const groupRepository = dataSource.getRepository(Group);

    const groups = await groupRepository.save([
      {
        name: 'Yoga Enthusiasts',
        description: 'Nhóm dành cho những người yêu thích yoga và thiền',
        createdBy: users[0],
      },
      {
        name: 'Fitness Challenge',
        description: 'Cùng nhau thực hiện thách thức thể dục',
        createdBy: users[1],
      },
      {
        name: 'Cooking Club',
        description: 'Chia sẻ công thức nấu ăn và kinh nghiệm',
        createdBy: users[2],
      },
    ]);

    console.log(`✅ Created ${groups.length} groups`);

    // Add members to groups
    console.log('➕ Adding members to groups...');
    const groupMemberRepository = dataSource.getRepository(GroupMember);

    const groupMembers = await groupMemberRepository.save([
      { group: groups[0], user: users[0], role: 'admin' },
      { group: groups[0], user: users[1], role: 'member' },
      { group: groups[0], user: users[3], role: 'member' },
      { group: groups[1], user: users[1], role: 'admin' },
      { group: groups[1], user: users[0], role: 'member' },
      { group: groups[1], user: users[2], role: 'member' },
      { group: groups[2], user: users[2], role: 'admin' },
      { group: groups[2], user: users[3], role: 'member' },
    ]);

    console.log(`✅ Added ${groupMembers.length} group members`);

    console.log('\n✨ Database seeding completed successfully!');
    console.log('\n📝 Test Accounts:');
    console.log('  alice@moodi.com / password123');
    console.log('  bob@moodi.com / password123');
    console.log('  charlie@moodi.com / password123');
    console.log('  diana@moodi.com / password123');
  } catch (error) {
    console.error('❌ Error during seeding:', error);
  } finally {
    await dataSource.destroy();
  }
}

seed();
