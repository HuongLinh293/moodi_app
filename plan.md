# 🎯 Moodi App - Kế hoạch phát triển toàn diện

**Ngày cập nhật**: 20/10/2024  
**Status**: 🔄 Chuyển đổi từ Firebase → NestJS

---

## 📊 Tổng quan dự án

### Hiện trạng
- ✅ Flutter app với Firebase backend
- ✅ Giao diện: Nhật ký, Vườn, Bạn bè (cơ bản)
- ❌ NestJS backend chưa có
- ❌ PostgreSQL database chưa setup
- ❌ WebSocket chat chưa có

### Mục tiêu
Xây dựng **social wellness app** hoàn chỉnh với:
- Ghi chép cảm xúc hàng ngày
- Vườn tương tác cộng đồng
- Kết bạn & nhóm
- Chat realtime
- Chia sẻ bài viết

---

## 🏗️ Kiến trúc hệ thống

### Frontend - Flutter
```
lib/
├── screens/          # Giao diện
├── repositories/     # Gọi API
├── state/           # State management
├── widgets/         # Thành phần UI
├── models/          # Data models
├── core/            # API client, config
└── main.dart
```

### Backend - NestJS
```
src/
├── auth/            # 🔐 Xác thực
├── users/           # 👤 Hồ sơ người dùng
├── posts/           # 📝 Bài viết
├── groups/          # 👥 Nhóm
├── friends/         # 🤝 Kết bạn
├── chat/            # 💬 Chat + WebSocket
├── storage/         # 🖼️ Upload ảnh
├── notifications/   # 🔔 Thông báo
└── common/          # 🛠️ Công cụ chung
```

### Database - PostgreSQL
```
users              # Tài khoản người dùng
posts              # Bài viết
comments           # Bình luận
post_likes         # Thích bài
friends            # Quan hệ bạn bè
friend_requests    # Lời kết bạn
groups             # Nhóm
group_members      # Thành viên nhóm
conversations      # Cuộc trò chuyện
messages           # Tin nhắn
storage_files      # Lưu ảnh
```

---

## 📅 Lộ trình phát triển

### **PHASE 1: Backend Setup (Tuần 1-2)**

#### Task 1.1: Tạo NestJS project
- [ ] Cài đặt NestJS CLI
- [ ] Tạo project skeleton
- [ ] Setup TypeORM + PostgreSQL
- [ ] Cấu hình environment variables
- [ ] Setup Docker + docker-compose
- **Thời gian**: 3 giờ
- **Deliverable**: Repo NestJS hoạt động

#### Task 1.2: Database schema
- [ ] Thiết kế entities (users, posts, friends, groups, messages)
- [ ] Tạo migrations
- [ ] Setup relations giữa tables
- [ ] Seed dữ liệu test
- **Thời gian**: 4 giờ
- **Deliverable**: PostgreSQL schema hoàn chỉnh

#### Task 1.3: Authentication module
- [ ] Implement register endpoint
- [ ] Implement login endpoint (JWT)
- [ ] Setup refresh token
- [ ] Implement password hashing (bcrypt)
- [ ] Implement JWT guards
- [ ] Implement decorators (@CurrentUser, @Roles)
- **Thời gian**: 5 giờ
- **Deliverable**: Auth endpoints test được trên Postman

#### Task 1.4: User module
- [ ] GET /users/:id (lấy hồ sơ)
- [ ] PATCH /users/:id (cập nhật hồ sơ)
- [ ] PATCH /users/:id/avatar (upload avatar)
- [ ] GET /users/search (tìm kiếm)
- **Thời gian**: 3 giờ
- **Deliverable**: User endpoints hoàn chỉnh

**Subtotal Phase 1**: ~15 giờ

---

### **PHASE 2: Core Features Backend (Tuần 3-4)**

#### Task 2.1: Posts module
- [ ] POST /posts (tạo bài viết)
- [ ] GET /posts (danh sách + pagination)
- [ ] GET /posts/:id (chi tiết)
- [ ] PATCH /posts/:id (sửa)
- [ ] DELETE /posts/:id (xoá)
- [ ] POST /posts/:id/like (thích)
- [ ] DELETE /posts/:id/like (bỏ thích)
- [ ] GET /posts/:id/comments (bình luận)
- **Thời gian**: 6 giờ
- **Deliverable**: Posts API đầy đủ

#### Task 2.2: Friends module
- [ ] POST /friends/requests (gửi lời kết bạn)
- [ ] GET /friends/requests (danh sách yêu cầu)
- [ ] POST /friends/requests/:id/accept (chấp nhận)
- [ ] DELETE /friends/requests/:id (từ chối)
- [ ] GET /friends (danh sách bạn bè)
- [ ] DELETE /friends/:id (xoá bạn)
- [ ] GET /friends/suggestions (gợi ý)
- **Thời gian**: 4 giờ
- **Deliverable**: Friends system hoạt động

#### Task 2.3: Groups module
- [ ] POST /groups (tạo nhóm)
- [ ] GET /groups (danh sách nhóm)
- [ ] GET /groups/:id (chi tiết)
- [ ] PATCH /groups/:id (sửa)
- [ ] DELETE /groups/:id (xoá)
- [ ] POST /groups/:id/members (thêm thành viên)
- [ ] DELETE /groups/:id/members/:userId (xoá thành viên)
- [ ] POST /groups/:id/invite (gửi lời mời)
- [ ] GET /groups/:id/invites (danh sách lời mời)
- **Thời gian**: 5 giờ
- **Deliverable**: Groups management đầy đủ

#### Task 2.4: Storage module
- [ ] POST /storage/upload (upload ảnh)
- [ ] GET /storage/:id (xem ảnh - kiểm tra quyền)
- [ ] DELETE /storage/:id (xoá ảnh)
- [ ] Setup file access control
- **Thời gian**: 3 giờ
- **Deliverable**: File upload & access control

**Subtotal Phase 2**: ~18 giờ

---

### **PHASE 3: Chat & WebSocket (Tuần 4-5)**

#### Task 3.1: Chat REST API
- [ ] GET /chat/conversations (danh sách cuộc chat)
- [ ] GET /chat/conversations/:id/messages (lịch sử)
- [ ] POST /chat/conversations (tạo cuộc chat)
- [ ] DELETE /chat/conversations/:id (xoá)
- [ ] PUT /chat/conversations/:id (đánh dấu đã đọc)
- **Thời gian**: 3 giờ
- **Deliverable**: Chat REST API

#### Task 3.2: WebSocket Gateway
- [ ] Tạo chat.gateway.ts
- [ ] Implement event: send_message
- [ ] Implement event: typing (đang gõ)
- [ ] Implement event: online_status (trạng thái)
- [ ] Implement JWT auth cho WebSocket
- [ ] Setup room-based messaging
- **Thời gian**: 6 giờ
- **Deliverable**: Real-time chat hoạt động

#### Task 3.3: Notifications (optional)
- [ ] POST /notifications (tạo thông báo)
- [ ] GET /notifications (danh sách)
- [ ] PUT /notifications/:id (đánh dấu đã xem)
- **Thời gian**: 2 giờ
- **Deliverable**: Basic notifications

**Subtotal Phase 3**: ~11 giờ

---

### **PHASE 4: Flutter App - Repositories (Tuần 5-6)**

#### Task 4.1: Update AuthRepository
- [ ] Xoá Firebase Auth imports
- [ ] Thêm REST API calls
- [ ] POST /auth/register
- [ ] POST /auth/login
- [ ] POST /auth/refresh-token
- [ ] Token storage & management
- **Thời gian**: 2 giờ
- **Deliverable**: Auth repository hoàn chỉnh

#### Task 4.2: Create UserRepository
- [ ] GET /users/:id
- [ ] PATCH /users/:id
- [ ] GET /users/search
- [ ] Avatar upload
- **Thời gian**: 2 giờ
- **Deliverable**: User repository

#### Task 4.3: Create PostRepository
- [ ] GET /posts (với pagination)
- [ ] POST /posts (tạo bài)
- [ ] PATCH /posts/:id
- [ ] DELETE /posts/:id
- [ ] Like/unlike
- **Thời gian**: 2 giờ
- **Deliverable**: Posts repository

#### Task 4.4: Create FriendRepository
- [ ] GET /friends
- [ ] POST /friends/requests
- [ ] Accept/reject requests
- [ ] Friend suggestions
- **Thời gian**: 2 giờ
- **Deliverable**: Friends repository

#### Task 4.5: Create GroupRepository
- [ ] GET /groups
- [ ] POST /groups
- [ ] Group management
- [ ] Member management
- **Thời gian**: 2 giờ
- **Deliverable**: Groups repository

#### Task 4.6: Create ChatRepository
- [ ] REST: GET /chat/conversations
- [ ] REST: GET /chat/conversations/:id/messages
- [ ] WebSocket: sendMessage()
- [ ] WebSocket: listenMessages()
- [ ] WebSocket: onTyping()
- [ ] WebSocket: onlineStatus()
- **Thời gian**: 3 giờ
- **Deliverable**: Chat repository with WebSocket

#### Task 4.7: Create StorageRepository
- [ ] POST /storage/upload
- [ ] File handling
- [ ] Progress tracking
- **Thời gian**: 1 giờ
- **Deliverable**: Storage repository

**Subtotal Phase 4**: ~14 giờ

---

### **PHASE 5: Flutter App - Screens (Tuần 6-7)**

#### Task 5.1: Update Auth screens
- [ ] Update LoginView
- [ ] Create RegisterView
- [ ] Implement token refresh
- [ ] Auto-logout on token expire
- **Thời gian**: 3 giờ
- **Deliverable**: Auth screens hoạt động

#### Task 5.2: Create Posts screens
- [ ] PostsListView (danh sách bài viết)
- [ ] CreatePostView
- [ ] EditPostView
- [ ] PostDetailView
- [ ] Like/unlike UI
- **Thời gian**: 4 giờ
- **Deliverable**: Posts screens

#### Task 5.3: Create Friends screens
- [ ] FriendsListView
- [ ] FriendRequestsView
- [ ] AddFriendView
- [ ] UserProfileView (tệp hồ sơ người khác)
- **Thời gian**: 3 giờ
- **Deliverable**: Friends screens

#### Task 5.4: Create Groups screens
- [ ] GroupsListView
- [ ] GroupDetailView
- [ ] CreateGroupView
- [ ] GroupMembersView
- [ ] GroupInvitesView
- **Thời gian**: 4 giờ
- **Deliverable**: Groups screens

#### Task 5.5: Update Chat screens
- [ ] ConversationsListView
- [ ] ChatView (with WebSocket)
- [ ] Real-time message updates
- [ ] Typing indicators
- [ ] Online status
- **Thời gian**: 4 giờ
- **Deliverable**: Chat screens with real-time

#### Task 5.6: Update Profile screens
- [ ] MyProfileView
- [ ] EditProfileView
- [ ] Avatar upload
- [ ] Settings
- **Thời gian**: 2 giờ
- **Deliverable**: Profile screens

**Subtotal Phase 5**: ~20 giờ

---

### **PHASE 6: State Management (Tuần 7)**

#### Task 6.1: Update MindraState
- [ ] Replace Firebase listeners with API calls
- [ ] Implement polling for non-real-time data
- [ ] WebSocket integration
- [ ] Token refresh logic
- [ ] Error handling
- **Thời gian**: 4 giờ
- **Deliverable**: MindraState compatible với API

#### Task 6.2: Providers & Notifiers
- [ ] Create individual providers for each feature
- [ ] Authentication state
- [ ] User state
- [ ] Posts state
- [ ] Friends state
- [ ] Groups state
- [ ] Chat state
- **Thời gian**: 3 giờ
- **Deliverable**: Complete state management

**Subtotal Phase 6**: ~7 giờ

---

### **PHASE 7: Testing & Deployment (Tuần 8)**

#### Task 7.1: Backend Testing
- [ ] Unit tests cho repositories
- [ ] Integration tests cho API endpoints
- [ ] WebSocket tests
- [ ] Database migrations test
- **Thời gian**: 5 giờ
- **Deliverable**: Backend test coverage >80%

#### Task 7.2: Frontend Testing
- [ ] Widget tests cho screens
- [ ] Integration tests cho repositories
- [ ] Mock API responses
- **Thời gian**: 4 giờ
- **Deliverable**: Frontend test coverage >60%

#### Task 7.3: End-to-end Testing
- [ ] Full app flow testing
- [ ] User scenarios (signup → chat → post)
- [ ] Error scenarios
- [ ] Performance testing
- **Thời gian**: 4 giờ
- **Deliverable**: E2E tests hoàn chỉnh

#### Task 7.4: Deployment
- [ ] Setup Docker for backend
- [ ] Deploy to staging
- [ ] Database backups
- [ ] CI/CD setup (GitHub Actions)
- **Thời gian**: 3 giờ
- **Deliverable**: App deployed on staging

#### Task 7.5: Documentation
- [ ] API documentation (Swagger)
- [ ] Flutter app documentation
- [ ] Setup guide
- [ ] Deployment guide
- **Thời gian**: 2 giờ
- **Deliverable**: Complete documentation

**Subtotal Phase 7**: ~18 giờ

---

## 📊 Tóm tắt Timeline

| Phase | Nội dung | Thời gian | Tuần |
|-------|---------|----------|------|
| 1 | Backend Setup | 15 giờ | 1-2 |
| 2 | Core Backend | 18 giờ | 3-4 |
| 3 | Chat & WebSocket | 11 giờ | 4-5 |
| 4 | Flutter Repositories | 14 giờ | 5-6 |
| 5 | Flutter Screens | 20 giờ | 6-7 |
| 6 | State Management | 7 giờ | 7 |
| 7 | Testing & Deploy | 18 giờ | 8 |
| **TỔNG** | | **103 giờ** | **8 tuần** |

### Tính theo ngày làm việc (8 giờ/ngày)
- ~13 ngày x 8 giờ = 104 giờ
- **~2-3 tuần** nếu làm full-time
- **~6-8 tuần** nếu làm part-time (2-3 giờ/ngày)

---

## 🎯 Milestone chính

### ✅ Milestone 1: Backend hoạt động (Tuần 2)
- [ ] NestJS + PostgreSQL setup
- [ ] Auth API endpoints
- [ ] Database schema
- [ ] Test được trên Postman

### ✅ Milestone 2: Backend features đầy đủ (Tuần 4)
- [ ] Posts, Friends, Groups, Storage
- [ ] Chat REST API
- [ ] WebSocket Gateway
- [ ] All endpoints tested

### ✅ Milestone 3: Flutter repositories (Tuần 6)
- [ ] Tất cả repositories cập nhật
- [ ] State management sửa
- [ ] Ready để tích hợp UI

### ✅ Milestone 4: Flutter UI complete (Tuần 7)
- [ ] Tất cả screens updated
- [ ] Real-time chat hoạt động
- [ ] Features đầy đủ

### ✅ Milestone 5: Testing & Deploy (Tuần 8)
- [ ] Test coverage >80%
- [ ] Deploy staging
- [ ] Documentation
- [ ] Ready for production

---

## 🔄 Dependencies & Risks

### Dependencies
```
Backend Development
    ↓ (APIs ready)
Flutter Repositories
    ↓ (Repos working)
Flutter Screens
    ↓ (UI complete)
Testing & Deployment
```

### Risks & Mitigation
| Risk | Severity | Mitigation |
|------|----------|-----------|
| WebSocket complexity | Medium | Start simple, add features gradually |
| Database migration issues | Medium | Test migrations locally first |
| Token refresh problems | High | Implement refresh token interceptor |
| Real-time sync conflicts | Medium | Implement optimistic updates |
| PostgreSQL performance | Low | Add indexes, monitor queries |

---

## 💾 Git Workflow

### Branch Strategy
```
main (production)
  ├── staging (test)
  │   ├── feature/auth
  │   ├── feature/posts
  │   ├── feature/chat
  │   └── feature/friends
  └── develop (integration)
```

### Commit Convention
```
[BACKEND] auth: implement JWT strategy
[FRONTEND] posts: add posts list screen
[DATABASE] migrations: create posts table
[DOCS] api: document endpoints
```

---

## 📦 Deliverables

### Phase 1-3: Backend
- ✅ NestJS project
- ✅ PostgreSQL database
- ✅ 33 API endpoints
- ✅ WebSocket chat
- ✅ File upload service
- ✅ API documentation (Swagger)

### Phase 4-6: Flutter
- ✅ 7 repositories
- ✅ 12+ screens
- ✅ State management
- ✅ Real-time updates
- ✅ Error handling

### Phase 7: Testing
- ✅ Backend tests
- ✅ Frontend tests
- ✅ E2E tests
- ✅ Deployment scripts
- ✅ Documentation

---

## 🚀 Next Steps

### Immediate (Next 3 days)
1. [ ] Tạo NestJS project structure
2. [ ] Setup PostgreSQL + Docker
3. [ ] Tạo database schema
4. [ ] Start Auth module development

### Short-term (Next 2 weeks)
1. [ ] Complete Backend Phase 1-2
2. [ ] Test tất cả endpoints
3. [ ] Start Flutter repositories

### Medium-term (Next 4 weeks)
1. [ ] Complete Backend Phase 3
2. [ ] Complete Flutter Phase 4-5
3. [ ] Integration testing

### Long-term (Next 8 weeks)
1. [ ] Complete tất cả phases
2. [ ] Testing & optimization
3. [ ] Deploy to staging/production

---

## 👥 Team & Responsibilities

### Backend Developer
- [ ] NestJS API development
- [ ] Database design
- [ ] WebSocket implementation
- [ ] API documentation
- **Est. 50 giờ**

### Frontend Developer
- [ ] Flutter repositories
- [ ] UI screens
- [ ] State management
- [ ] Testing
- **Est. 40 giờ**

### DevOps (Optional)
- [ ] Docker setup
- [ ] CI/CD
- [ ] Deployment
- [ ] Monitoring
- **Est. 10 giờ**

---

## 📝 Notes

### Assumptions
- PostgreSQL 14+ available
- Node.js 18+ installed
- Flutter SDK latest
- Docker available

### Constraints
- Limited to MVP features (no AI/recommendations first)
- No video support initially
- No offline mode initially
- Single region deployment

### Future Enhancements
- [ ] AI-powered recommendations
- [ ] Video calls
- [ ] Offline mode
- [ ] Multi-region deployment
- [ ] Mobile payments
- [ ] Advanced analytics

---

## 📞 Questions & Decisions

**Q1: Nên dùng WebSocket hay Server-Sent Events (SSE)?**
- **A**: WebSocket - tốt hơn cho 2-way real-time communication

**Q2: Database nên dùng PostgreSQL hay MySQL?**
- **A**: PostgreSQL - advanced features, JSON support

**Q3: Frontend dùng Provider hay Riverpod?**
- **A**: Provider - đơn giản, dễ bảo trì

**Q4: Nên implement cache?**
- **A**: Có - dùng hive hoặc sqflite để offline cache

**Q5: Nên implement pagination từ lúc nào?**
- **A**: Từ Phase 2 - bắt buộc cho danh sách

---

## 📅 Timeline Chart

```
Week 1-2 : [Backend Setup #########]
Week 3-4 : [Core Backend ####################]
Week 4-5 : [Chat & WebSocket ##########]
Week 5-6 : [Flutter Repos ############]
Week 6-7 : [Flutter Screens ####################]
Week 7   : [State Mgmt #######]
Week 8   : [Testing ##################]
```

---

**Status**: 🟡 In Progress - Backend Phase 1  
**Last Updated**: 20/10/2024  
**Next Review**: 27/10/2024
