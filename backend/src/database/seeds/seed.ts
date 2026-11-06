import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { databaseConfig } from '../../config/database.config';
import { User } from '../../users/entities/user.entity';

// Tạo tài khoản test nếu chưa có. Không xóa dữ liệu nào nên chạy lại nhiều lần
// vẫn an toàn. Hồ sơ Cộng đồng do người dùng tự tạo trong app.
const TEST_USERS = [
  { email: 'alice@moodi.com', username: 'alice', displayName: 'Alice Wonder', bio: 'Chia sẻ những khoảnh khắc tốt đẹp' },
  { email: 'bob@moodi.com', username: 'bob', displayName: 'Bob Builder', bio: 'Đam mê thể dục và sức khỏe' },
  { email: 'charlie@moodi.com', username: 'charlie', displayName: 'Charlie Chocolate', bio: 'Yêu nấu ăn và du lịch' },
  { email: 'diana@moodi.com', username: 'diana', displayName: 'Diana Princess', bio: 'Nghệ sĩ tự do' },
];

async function seed() {
  const dataSource = new DataSource({ ...databaseConfig(), logging: false } as any);
  await dataSource.initialize();
  console.log('✅ Database connected');

  try {
    const users = dataSource.getRepository(User);
    const password = await bcrypt.hash('password123', 10);
    let created = 0;
    for (const account of TEST_USERS) {
      if (await users.existsBy({ email: account.email })) continue;
      await users.save(users.create({ ...account, password, isVerified: true }));
      created++;
    }
    console.log(`✅ Created ${created} new test users (${TEST_USERS.length - created} already existed)`);
    console.log('\n📝 Test Accounts (password123):');
    for (const account of TEST_USERS) console.log(`  ${account.email}`);
  } catch (error) {
    console.error('❌ Error during seeding:', error);
    process.exitCode = 1;
  } finally {
    await dataSource.destroy();
  }
}

seed();
