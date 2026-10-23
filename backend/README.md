# 🚀 Moodi Backend - NestJS

Moodi Social Wellness App Backend API

## 📋 Yêu cầu

- Node.js 18+
- PostgreSQL 14+
- Docker & Docker Compose (tùy chọn)

## 🚀 Cài đặt

### 1. Clone repo và cài dependencies
```bash
cd backend
npm install
```

### 2. Cấu hình Environment
```bash
cp .env.example .env
# Sửa .env với các giá trị của bạn
```

### 3. Chạy Database (Docker)
```bash
docker-compose up -d
```

### 4. Migrations
Không cần chạy riêng: ngoài production, schema tự đồng bộ và migration tự chạy khi server khởi động (`migrationsRun: true` trong `src/config/database.config.ts`).

### 5. Seed dữ liệu test (tùy chọn)
```bash
npm run seed
```

### 6. Chạy Dev Server
```bash
npm run start:dev
```

Server sẽ chạy tại: `http://localhost:3000`  
API Docs: `http://localhost:3000/docs`

## 📚 API Endpoints

### Authentication
- `POST /api/auth/register` - Đăng ký
- `POST /api/auth/login` - Đăng nhập
- `POST /api/auth/refresh-token` - Làm mới token

### Users (TODO)
- `GET /api/users/:id` - Lấy hồ sơ
- `PATCH /api/users/:id` - Cập nhật hồ sơ

### Posts (TODO)
- `GET /api/posts` - Danh sách bài
- `POST /api/posts` - Tạo bài
- `PATCH /api/posts/:id` - Sửa bài
- `DELETE /api/posts/:id` - Xoá bài

### Groups (TODO)
- `GET /api/groups` - Danh sách nhóm
- `POST /api/groups` - Tạo nhóm

### Friends (TODO)
- `GET /api/friends` - Danh sách bạn
- `POST /api/friends/requests` - Gửi lời kết bạn

### Chat (TODO)
- `GET /api/chat/conversations` - Danh sách chat
- `WS /api/chat` - WebSocket realtime

### Storage (TODO)
- `POST /api/storage/upload` - Upload ảnh
- `GET /api/storage/:id` - Xem ảnh

## 🏗️ Cấu trúc Thư mục

```
src/
├── auth/              # Authentication module
├── users/             # User profiles
├── posts/             # Posts module
├── groups/            # Groups module
├── friends/           # Friends module
├── chat/              # Chat module
├── storage/           # File storage
├── notifications/     # Notifications
├── common/            # Decorators, filters, etc
├── config/            # Configuration
├── database/          # Migrations, seeds
├── app.module.ts      # Main app module
└── main.ts            # Entry point
```

## 🔐 Authentication

API sử dụng **JWT Bearer Token**

Thêm vào header:
```
Authorization: Bearer <your_access_token>
```

## 📖 Development

### Tạo service mới
```bash
nest generate service posts
```

### Tạo controller
```bash
nest generate controller posts
```

### Chạy tests
```bash
npm run test
npm run test:watch
npm run test:cov
```

### Lint & Format
```bash
npm run lint
npm run format
```

## 📦 Build & Deploy

### Build production
```bash
npm run build
```

### Chạy production
```bash
npm run start:prod
```

## 🗄️ Database

### Tạo migration
```bash
npm run migration:generate -- src/database/migrations/CreateUsersTable
```

### Revert migration
```bash
npm run migration:revert
```

## 🐛 Troubleshooting

### Database connection refused
```bash
# Kiểm tra PostgreSQL chạy
docker-compose ps

# Restart
docker-compose restart postgres
```

### Port already in use
```bash
# Sửa PORT trong .env hoặc
kill -9 $(lsof -ti :3000)
```

### Migrations failed
```bash
# Xoá tất cả tables và chạy lại
docker-compose down -v
docker-compose up -d
npm run migration:run
```

## 📝 Notes

- JWT Expiration: 1 giờ (ACCESS_TOKEN)
- Refresh Token: 7 ngày (REFRESH_TOKEN)
- Max file upload: 10MB
- CORS enabled cho: `http://localhost:3000`

## 🤝 Contributing

1. Tạo branch: `git checkout -b feature/name`
2. Commit: `git commit -m '[BACKEND] feature: description'`
3. Push: `git push origin feature/name`

## 📄 License

MIT
