# Review UI/UX và luồng hoạt động Moodi

Ngày review: **06/11/2026**. Code nền: commit `e94c071`, cộng trạng thái working tree tại thời điểm review. Đây là báo cáo đánh giá; chưa sửa logic hay giao diện sản phẩm.

## 1. Kết luận

Moodi có hướng hình ảnh rõ: nền giấy ấm, chữ đậm, màu cảm xúc, mặt biểu cảm và khu vườn origami. Cấu trúc bốn tab khá dễ hiểu; check-in nhanh và đầy đủ đã được tách; cộng đồng có nhiều xử lý lỗi và quyền truy cập tốt hơn một bản demo đơn thuần.

**Điểm cần ưu tiên hiện tại là tính đúng của dữ liệu và sự liên tục của hành trình.** Có lỗi ở lựa chọn cảm xúc đầu tiên, quay từ phản tư về nhật ký, bỏ chọn đánh giá bài tập, dữ liệu tạm dừng tự điền và xử lý ghi chép chưa đồng bộ. Những vấn đề này ảnh hưởng niềm tin nhiều hơn việc thay màu hoặc làm lại card.

Không có cơ sở để kết luận app đã sẵn sàng phát hành chỉ vì analyzer và test hiện tại đều xanh. Bộ kiểm tra bổ sung đã tái hiện lỗi trên những nhánh chưa có trong test cũ.

## 2. Phạm vi và giới hạn bằng chứng

### Đã thực hiện

- Đọc cấu trúc Flutter, 17 file màn hình, 7 file cộng đồng, state trung tâm, repositories, models, theme và các widget phục vụ luồng chính.
- Đối chiếu các API liên quan tại NestJS: xác thực, entries, moments, reflections và community. Không thực hiện audit bảo mật backend toàn diện.
- Chạy `flutter analyze`: **không có issue**.
- Chạy toàn bộ test Flutter có sẵn: **96 test passed**.
- Chạy test backend: **3 suite, 24 test passed**.
- Dùng probe tạm thời để kiểm tra thêm 6 hành vi và render 12 trạng thái màn hình ở hai cấu hình: **390×844, chữ 100%** và **320×568, chữ 200%**.
- Nạp font Plus Jakarta Sans thật trước khi render. Không dùng kết quả lượt render ban đầu với font Ahem để kết luận lỗi.
- Tính độ tương phản trực tiếp từ token màu trong code.

### Chưa thực hiện / không được suy diễn là đã đạt

- API `http://localhost:3000/api/auth/providers` không kết nối được trong môi trường review. Chưa đăng nhập API thật, chưa kiểm tra DB thật, upload ảnh thật, gửi tin nhắn thật hay gọi Gemini thật.
- Các probe là unit/widget test với dữ liệu giả, **không phải integration test trên iPhone/Android thật**. Render không có đầy đủ status bar, bàn phím, safe area, font emoji và hành vi hệ điều hành như thiết bị thật.
- Chưa kiểm tra VoiceOver/TalkBack, tablet, bàn phím phần cứng, mạng chập chờn thật, push trên thiết bị, background/foreground kéo dài, hiệu năng bằng profiler.
- Chưa kiểm chứng tính cập nhật của thông tin nguồn hỗ trợ trong app. Không sử dụng thông tin này trong báo cáo như một khuyến nghị đã xác minh.
- Không chấm điểm UX bằng một con số vì chưa có usability test với người dùng, dữ liệu hoàn thành tác vụ hoặc đo thời gian thực tế.

### Đọc mức độ bằng chứng

- **Tái hiện:** có probe xác nhận hành vi hoặc lỗi render.
- **Theo code:** đường thực thi và dữ liệu thể hiện trực tiếp trong mã, chưa chạy với backend thật.
- **Rủi ro:** tình huống hợp lý suy ra từ mã; cần kiểm thử tích hợp trước khi kết luận xảy ra trong production.
- **Nhận định thiết kế:** đánh giá heuristic; cần kiểm chứng với người dùng.

P1: sửa trước khi beta có người dùng thật. P2: sửa để các hành trình chính ổn định và dễ hiểu. P3: hoàn thiện hoặc quyết định phạm vi sản phẩm. Mức độ là thứ tự ưu tiên đề xuất cho dự án này.

## 3. Bản đồ màn hình và luồng đang có

```text
Mở app
  → đọc preferences + khôi phục phiên
  → onboarding 3 trang nếu chưa hoàn thành
  → đăng nhập/đăng ký nếu chưa xác thực
  → khóa PIN demo nếu bật trong debug
  → HomeShell
       ├─ Hôm nay
       │    ├─ chọn cảm xúc → check-in nhanh/đầy đủ
       │    │    ├─ chỉ lưu → mời giữ trong vườn
       │    │    └─ lưu + phản tư → bài tập / bước nhỏ / nhật ký
       │    ├─ Nghỉ 30 giây → cơ thể → thở → cảm xúc → hành động
       │    ├─ Vò giấy → viết → vò → thả → hoàn tác ngắn hạn
       │    ├─ Bưu thiếp tuần
       │    ├─ bài tập ngắn → catalog mở bằng route riêng
       │    └─ xem trước khu vườn
       ├─ Góc riêng
       │    ├─ Nhật ký → lịch tháng → các entry trong ngày
       │    │    ├─ ghi bù / thêm / sửa / xóa
       │    │    ├─ giữ trong vườn
       │    │    └─ xem phản tư đã có trong cache
       │    └─ Khu vườn → tháng → hoa → chi tiết / bỏ hoa
       ├─ Cộng đồng
       │    ├─ tạo hồ sơ cộng đồng
       │    ├─ bảng tin / lọc cảm xúc / bài viết / đồng cảm / bình luận
       │    ├─ bạn bè bằng mã / lời mời / chặn / báo cáo
       │    ├─ tin nhắn / ảnh / lịch sử
       │    ├─ nhóm riêng / mời / thành viên / quản lý nhóm
       │    └─ thông báo / kiểm duyệt theo quyền
       └─ Khám phá
            ├─ Tiến trình → tuần / 7–30 ngày / nhịp lặp / nhìn lại / huy hiệu
            └─ Thực hành → lọc → giới thiệu → thực hành → hoàn thành → đánh giá

Tôi ở thanh trên → hồ sơ / sửa tên / cài đặt / đăng xuất
Cài đặt → mục tiêu / nhắc nhở / AI / giảm kích thích / vườn / xuất / xóa
```

**Phạm vi thực sự:** vườn chung có model, repository, state và backend nhưng không được nối vào `GardenView` hiện tại. Chế độ khách có hạ tầng repository nhưng `LoginView` không có nút vào. Không tính hai tính năng này là hành trình UI hoàn chỉnh.

## 4. Findings cần ưu tiên

### F01 — P1 — Lần đầu chọn “Vui” không phát thông báo cập nhật UI

**Bằng chứng: tái hiện.** `lib/state/mindra_state.dart:526`.

State mặc định có `_selectedEmotionKey = 'happy'` và `_hasChosenEmotion = false`. `selectEmotion('happy')` đổi cờ thành true nhưng chỉ gọi `notifyListeners()` khi key khác key cũ. Probe ghi nhận cờ đã đổi nhưng số notification bằng 0.

**Luồng:** mở app chưa chọn cảm xúc → chạm Vui trên Hôm nay hoặc trong check-in. UI có thể tiếp tục hiện trạng thái chưa chọn và nút lưu vẫn mang trạng thái cũ tới khi có một lần rebuild khác. Nếu polling gây rebuild sau đó thì lỗi bị che khuất, tạo cảm giác lúc được lúc không.

**Sửa:** coi việc chuyển từ chưa chọn sang đã chọn là thay đổi cần notify, kể cả key giữ nguyên. **Đạt khi:** lần chọn đầu tiên của mọi cảm xúc đều cập nhật ngay; riêng Vui có test regression từ trạng thái rỗng.

### F02 — P1 — Từ phản tư về nhật ký có thể dùng context của sheet đã đóng

**Bằng chứng: tái hiện.** `lib/screens/checkin_view.dart:99`, `lib/screens/home_shell.dart:735`, `lib/screens/ai_reflection_view.dart:1244`.

**Luồng:** Hôm nay → Ghi nhận thêm → Đầy đủ → Lưu & Xem gợi ý phản tư → Xem trong Lịch & Nhật ký. Probe nhận lỗi **`Null check operator used on a null value`**.

Callback `onOpenJournal` do HomeShell truyền vào check-in chứa `Navigator.pop(modalCtx)`. Check-in đã gọi `onClose` để đóng sheet trước khi mở phản tư, nhưng vẫn chuyển callback đó sang phản tư. Khi callback chạy sau đó, nó tham chiếu context của sheet đã bị dispose.

**Sửa:** sheet trả về một kết quả typed cho HomeShell; điều hướng tiếp từ context còn sống. Callback “mở nhật ký” từ phản tư chỉ cập nhật tab/section, không pop sheet cũ. **Đạt khi:** phản tư mở từ check-in, mở từ nhật ký, đóng bằng X, back và xem nhật ký đều đúng đích, không exception.

### F03 — P1 — Ghi chép chưa đồng bộ có thể mất khi app bị đóng

**Bằng chứng: theo code.** `lib/state/mindra_state.dart:594`, `lib/state/mindra_state.dart:616`, `lib/widgets/entry_sync_notice.dart:35`.

Entry và trạng thái pending/failed đang giữ trong `_entries`, `_entrySync`, các Future trong RAM. Preferences và nội dung mục tiêu có lưu bền, nhưng không có kho bền cho queue entry chưa gửi. Cảnh báo “giữ ứng dụng mở” đang thừa nhận giới hạn này.

**Luồng:** đang offline → viết đầy đủ → lưu → thấy entry trong nhật ký → hệ điều hành đóng tiến trình → mở lại → entry chưa lên server không thể phục hồi từ các kho lưu hiện có.

**Sửa:** lưu local transaction trước, đánh dấu chờ đồng bộ và retry từ outbox bền theo tài khoản. Phân biệt “đã lưu trên máy” và “đã đồng bộ”. **Đạt khi:** force-close ngay khi pending và sau khi failed vẫn khôi phục nội dung; retry không tạo trùng; logout có cách xử lý dữ liệu chưa gửi rõ ràng.

### F04 — P1 — Tạm dừng tự tạo cảm xúc và mức cải thiện người dùng chưa báo

**Bằng chứng: tái hiện.** `lib/screens/pause_mode_sheet.dart:160`.

Chọn “Tôi không chắc / Rất mơ hồ”, bỏ qua thở rồi hoàn thành vẫn tạo entry `calm`, `intensity = 3`, `afterIntensity = 2`, `exerciseDone = true`. Trường thought cũng có thể lấy `defaultThought` của cảm xúc thay vì lời người dùng.

**Tác động:** nhật ký, phân bố cảm xúc và card chuyển biến sau thực hành ghi một cải thiện do app giả định. “Không rõ” bị diễn giải thành “Bình yên”.

**Sửa:** ghi riêng một sự kiện đã tạm dừng; cảm xúc chưa rõ giữ null/unknown; chỉ có after khi người dùng nhập. Thought gợi ý phải khác thought tự viết. **Đạt khi:** bỏ qua, không chắc, không đổi, xấu đi đều được lưu trung thực; không tự mặc định cải thiện.

### F05 — P1 — Bỏ chọn đánh giá bài tập có thể ném `StateError`

**Bằng chứng: tái hiện callback của widget thật.** `lib/screens/practice_session.dart:572`, `lib/screens/practice_session.dart:745`.

Scale hữu ích/dễ thực hiện và lựa chọn dùng lại cho phép `emptySelectionAllowed: true`, nhưng handler gọi `selection.first`. Sau khi chọn một đáp án rồi chạm lại để bỏ chọn, tập lựa chọn có thể rỗng. Probe xác nhận handler của scale ném `StateError` với tập rỗng.

**Sửa:** xử lý empty → null, hoặc không cho bỏ chọn nếu đó là yêu cầu sản phẩm. **Đạt khi:** chọn, đổi lựa chọn và bỏ chọn trên cả ba nhóm không lỗi, không mất nội dung khác.

### F06 — P1 — Sửa nhật ký chưa làm phản tư phía server cập nhật theo nội dung mới

**Bằng chứng: theo code.** `lib/state/mindra_state.dart:576`, `backend/src/reflections/reflections.service.ts:47`.

App xóa cache phản tư khi emotion/intensity/situation/thought đổi. Tuy nhiên server tìm phản tư theo `userId + entryId` rồi trả `existing` nếu không có tín hiệu khủng hoảng. Không so phiên bản hoặc hash nội dung mới. Chỉ làm mất cache ở client không đủ để tạo lại phản tư.

**Luồng:** tạo phản tư cho ghi chép A → sửa ghi chép thành B với nội dung khác → lần gọi generate tiếp vẫn có thể lấy phản tư A. Hiện tại nút xem phản tư còn có thể biến mất ngay sau sửa vì nó phụ thuộc cache, làm vấn đề khó thấy hơn.

**Sửa:** gắn reflection với phiên bản/hash entry, invalidation server khi sửa, hoặc thao tác tạo lại rõ ràng. **Đạt khi:** sửa bối cảnh/suy nghĩ/cảm xúc tạo phản tư tương ứng; bản safety luôn được ưu tiên; phản hồi cũ tới muộn không ghi đè bản mới.

### F07 — P1 — Luồng dữ liệu tuần có thể báo số liệu lịch sử là “tuần này”

**Bằng chứng: tái hiện.** `lib/state/mindra_state.dart:458`, `lib/state/mindra_state.dart:465`, `lib/state/mindra_state.dart:483`.

Nếu `thisWeekEntries` rỗng, các getter trung bình cường độ/cảm xúc nổi bật/tác nhân nổi bật fallback sang toàn bộ `_entries`. Probe với duy nhất một entry cách 40 ngày ghi nhận **0 ngày tuần này** nhưng **cường độ tuần = 5, cảm xúc nổi bật = angry**.

**Sửa:** tuần rỗng phải hiện chưa đủ dữ liệu. Nếu muốn fallback lịch sử, tách card và ghi khoảng ngày cụ thể. **Đạt khi:** 0 entry tuần này không sinh kết luận tuần từ lịch sử; phân biệt tuần lịch và 7 ngày gần nhất.

### F08 — P1 — Xóa ghi chép chưa dọn toàn bộ dữ liệu phản tư liên quan

**Bằng chứng: theo code.** `lib/state/mindra_state.dart:642`, `lib/state/mindra_state.dart:1374`, `backend/src/entries/entries.service.ts:88`, `backend/src/reflections/entities/ai-reflection.entity.ts:25`.

Xóa entry không xóa `_aiReflections` tương ứng. Xóa nhật ký và hoa gọi các API entries/moments, còn bảng `ai_reflections` chỉ có quan hệ với user, không có cascade từ entry. Kết quả phản tư có thể chứa nội dung suy ra hoặc trích từ ghi chép đã xóa.

Không đánh đồng thao tác hiện tại với “xóa tài khoản”: UI đã nói riêng bài cộng đồng và tin nhắn không thuộc thao tác này. Vấn đề ở đây là **dữ liệu phát sinh từ chính nhật ký** còn tồn tại mà chưa có phạm vi giữ/xóa rõ ràng.

**Sửa:** định nghĩa lifecycle entry–reflection, xóa đồng bộ trong transaction, dọn cache và request đang chạy. **Đạt khi:** xóa entry/xóa nhật ký loại bỏ phản tư liên quan khỏi client và API history; kết quả tới muộn không hồi sinh dữ liệu đó.

### F09 — P1 — Các lần sửa cùng một entry có thể ghi lên server sai thứ tự

**Bằng chứng: rủi ro theo code, chưa tái hiện với DB thật.** `lib/state/mindra_state.dart:594`, `lib/state/mindra_state.dart:616`, `backend/src/entries/entries.service.ts:65`.

Mỗi lần sửa khởi chạy một request độc lập. `_entryWriteVersions` bảo vệ trạng thái ACK trong client, nhưng request phiên bản cũ vẫn được server lưu bình thường.

**Kịch bản cần test:** gửi A → sửa nhanh thành B → server xử lý B trước A → B được đánh dấu synced → A tới sau ghi đè B → polling nhận A. Không có version kiểm tra ở server hoặc hàng đợi tuần tự theo entry để ngăn tình huống này.

**Sửa:** serialize write theo entry hoặc optimistic concurrency bằng revision. **Đạt khi:** cố tình đảo thứ tự xử lý request vẫn giữ nội dung người dùng sửa cuối cùng; retry cũ không ghi đè mới.

### F10 — P1 — Chữ lớn làm hỏng bố cục ở các luồng nhập và hoàn thành chính

**Bằng chứng: render với font thật.** Xem ma trận ở mục 7.

Ở 320×568, text scale 2.0, onboarding tràn dưới 369 logical pixels, giới thiệu bài tập tràn dưới khoảng 305 pixels, check-in tràn ngang 95 pixels. Nhật ký có 30 lỗi overflow trên ô ngày; các màn khác có lỗi ở tiêu đề hoặc hàng điều khiển.

**Sửa:** nội dung dài có scroll; tránh `Column + Spacer` trong vùng cao cố định khi text lớn; thay Row cố định bằng Wrap/Flexible thích hợp; ô lịch có kích thước theo text; CTA không có chiều cao cứng nếu label cần xuống dòng. Không dùng scale-down toàn bộ chữ để chỉ làm hết báo lỗi.

**Đạt khi:** text 100/150/200%, 320/375/390 logical width, có/không bàn phím đều đọc và thao tác được; không clip nội dung hoặc che CTA.

## 5. Findings về hành trình, lưu trữ và khả năng sử dụng

### F11 — P2 — Tải dữ liệu ban đầu chưa phân biệt loading, empty và lỗi

**Theo code:** `lib/repositories/journal_repository.dart:137`, `lib/repositories/garden_repository.dart:106`, `lib/state/mindra_state.dart:1648`.

Stream polling chỉ phát yêu cầu đầu tiên sau chu kỳ 5 giây. Lỗi đọc entries/moments trong state chủ yếu đi vào debug log, không thành trạng thái lỗi UI. Người có dữ liệu có thể thấy giao diện rỗng lúc mới đăng nhập hoặc khi server hỏng. Cài đặt suy “đã đồng bộ” từ không có write pending/failed, dù lần đọc chưa thành công.

**Sửa/đạt:** fetch ngay, lưu last-success/cache, có trạng thái đang tải/lỗi đọc/rỗng thật; nút thử lại; nhãn đồng bộ thể hiện thời điểm đọc thành công hoặc phạm vi chỉ là các lần ghi. Không hiển thị “hãy tạo ghi chép đầu tiên” khi chưa biết server có dữ liệu hay không.

### F12 — P2 — Chuyển tab làm mất vị trí và mục con đang xem

**Tái hiện:** `lib/screens/home_shell.dart:70`, `lib/screens/explore_view.dart:32`, `lib/screens/journal_view.dart:31`.

HomeShell thay child theo `ValueKey(currentTab)` và `_buildView`, không giữ bốn tab cùng tồn tại. `IndexedStack` bên trong Góc riêng/Khám phá chỉ bảo toàn state trong lúc tab cha còn sống. Probe xác nhận Thực hành → Hôm nay → Khám phá trở về Tiến trình. Tháng/ngày của lịch, bộ lọc và vị trí cuộn ở các màn khác cũng có nguy cơ reset theo cấu trúc này.

**Sửa/đạt:** giữ state tab bằng IndexedStack/lazy persistent tabs hoặc lưu state điều hướng cần thiết. Rời rồi quay lại phải giữ section, ngày/tháng, filter và scroll; thiết kế riêng hành vi chạm lại tab đang chọn.

### F13 — P2 — Đồng ý dùng AI đang bật mặc định, giải thích ở xa lần dùng đầu

**Theo code:** `lib/state/mindra_state.dart:1147`, `lib/screens/onboarding_view.dart:612`, `lib/screens/settings_view.dart:405`.

Cài đặt có mô tả khá rõ việc gửi nội dung tới Moodi và có thể tới Gemini. Tuy nhiên `_aiConsent` mặc định true; onboarding không có lựa chọn opt-in riêng hoặc nêu rõ nhà cung cấp ở điểm chuẩn bị gửi. Nút “Lưu & Xem gợi ý phản tư” có thể là lần đầu người dùng tiếp cận việc này.

**Sửa/đạt:** đặt lựa chọn ngay lần đầu dùng phản tư: dữ liệu nào gửi, đích xử lý, lựa chọn chỉ lưu. Lưu lựa chọn bền vững. Đây là đề xuất UX về sự minh bạch, không phải kết luận pháp lý. Cần kiểm tra thêm việc tắt trong khi request đang chạy và xác nhận phạm vi hủy.

### F14 — P2 — Chỉnh phản tư và phản hồi chỉ tồn tại trong cache phiên

**Theo code:** `lib/state/mindra_state.dart:347`, `lib/screens/ai_reflection_view.dart:173`, `lib/screens/ai_reflection_view.dart:1264`.

UI cho sửa và chọn Rất đúng/Cần sửa/Chưa hợp, nhưng `updateAIReflection` chỉ sửa Map trong RAM. Repository có hàm gửi feedback, nhưng các thao tác này không gọi nó. Mở lại app có thể nhận bản cũ từ server. `_openReflectionEditor` dùng `_reflection` gốc, trong khi sau khi sửa chỉ cập nhật các trường hiển thị; mở editor lần hai có thể thấy nội dung trước sửa.

**Sửa/đạt:** định nghĩa bản người dùng chỉnh và bản AI riêng, lưu bền và báo trạng thái lưu; editor lấy `_currentReflection`. Chỉnh hai lần, đóng mở màn và khởi động lại đều giữ bản cuối; feedback tới backend đúng entry.

### F15 — P2 — Nhiều buổi thực hành trong ngày bị dồn vào một entry

**Theo code:** `lib/state/mindra_state.dart:1079`, `lib/screens/practice_session.dart:603`.

`completeExercise` gắn vào entry đầu tiên của hôm nay, ghi đè `exerciseId`, after/rating của lần trước. Vì model chỉ có một exercise trên một journal entry nên không thể giữ đầy đủ nhiều buổi. Nếu bài tập mở từ phản tư của entry cũ, việc lưu vẫn nhắm entry hôm nay, không phải entry nguồn. Phần “Trước” lại lấy selectedEmotion/currentIntensity toàn cục, có thể khác entry được cập nhật.

**Sửa/đạt:** tách `PracticeSession` thành bản ghi độc lập, có optional entryId nguồn và before/after snapshot riêng. Hai bài trong một ngày vẫn có hai phiên, thống kê đúng; thực hành từ entry hôm qua không âm thầm sửa nhầm hôm nay.

### F16 — P2 — Cảm xúc sau bài tập được chọn sẵn và một số state tạm không reset theo tài khoản

**Theo code:** `lib/screens/practice_session.dart:525`, `lib/screens/practice_session.dart:203`, `lib/state/mindra_state.dart:108`, `lib/state/mindra_state.dart:1534`.

Màn afterCheckin gán `_afterEmotionKey = selectedEmotionKey` và cường độ toàn cục trước khi người dùng trả lời. Nếu chưa chọn cảm xúc thật, default vẫn có thể thành dữ liệu. Các nhánh đổi auth/logout dọn entries nhưng không reset `_hasChosenEmotion`, selected emotion, intensity và tab như một session UI mới.

**Sửa/đạt:** trạng thái “chưa trả lời” riêng; cho “không muốn ghi” rõ ràng. Reset state nháp theo tài khoản. Sau logout A → login B, B không thừa lựa chọn cảm xúc hoặc cường độ từ A; after không tự ghi khi chưa được xác nhận.

### F17 — P2 — “Sửa ghi chép” không cho sửa đủ những gì đã nhập ở check-in đầy đủ

**Theo code:** `lib/screens/journal_view.dart:117`, `lib/screens/journal_view.dart:373`, `lib/screens/journal_view.dart:1163`.

Editor nhật ký hiện sửa emotion/intensity/situation; không có thought/response/trigger đầy đủ. Card ưu tiên situation, chỉ hiện thought nếu situation rỗng, nên suy nghĩ và phản ứng có thể khó tìm lại. Dữ liệu không nhất thiết bị xóa nhưng người dùng không có đường đọc/sửa tương xứng với công sức đã nhập.

**Sửa/đạt:** card tóm tắt + màn chi tiết cho tất cả trường; chỉnh từ cùng cấu trúc với check-in đầy đủ. Ghi một entry có đủ ba trường rồi đọc và sửa độc lập từng trường được.

### F18 — P2 — Đóng check-in hoặc bài viết thực hành có thể mất nháp không cảnh báo

**Theo code:** `lib/screens/home_shell.dart:640`, `lib/screens/checkin_view.dart:37`, `lib/screens/practice_session.dart:145`.

Check-in sheet có X, dismiss và drag; không có dirty-state guard. Các TextEditingController bị dispose khi đóng. Session dạng viết cũng thoát trực tiếp. Trong khi đó composer cộng đồng đã có PopScope hỏi bỏ nháp, nên hành vi giữa dữ liệu riêng và bài công khai thiếu nhất quán.

**Sửa/đạt:** lưu nháp bền hoặc hỏi bỏ khi đã nhập; không hỏi nếu chưa đổi. X/back/swipe/tap ngoài/đưa app xuống nền đều có quy ước thống nhất; không tự gửi bản nháp cho AI.

### F19 — P2 — Giảm kích thích chưa áp dụng đồng đều và chưa theo thiết lập hệ điều hành

**Theo code:** `lib/core/theme/motion.dart:8`, `lib/screens/pause_mode_sheet.dart:117`, `lib/screens/ai_reflection_view.dart:87`, `lib/widgets/weekly_postcard_sheet.dart:43`.

Motion token phần lớn chỉ đọc cờ trong app. PaperRelease có kết hợp `MediaQuery.disableAnimations`, nhưng pulse phản tư, animation thở trong Pause, flip bưu thiếp và nhiều haptic trực tiếp chưa cùng chính sách. Pulse phản tư khởi chạy repeat ngay cả khi có cache.

**Sửa/đạt:** reduced = lựa chọn trong app hoặc OS; hướng dẫn thở vẫn giữ thời gian bằng text/countdown, chỉ bỏ phóng to/thu nhỏ. Dừng controller không dùng, pause khi background. Bật Reduce Motion của OS cũng có hiệu lực khi cờ app chưa bật.

### F20 — P2 — Màu cam và text tertiary chưa đủ tương phản ở nhiều ngữ cảnh

**Đo từ token:** `lib/core/theme/colors.dart:10`, `lib/core/theme/colors.dart:29`, `lib/screens/home_shell.dart:1028`, `lib/screens/login_view.dart:620`.

| Cặp màu | Tỷ lệ gần đúng | Diễn giải |
|---|---:|---|
| orange trên paper | 2.82:1 | Không đạt mốc chữ thường 4.5:1; dưới cả 3:1 cho chữ lớn |
| orange trên cream | 3.00:1 khi làm tròn | Không đủ cho caption/chữ nhỏ; không quyết định pass bằng số đã làm tròn |
| white trên orange | 3.12:1 | Không đủ cho chữ nút nhỏ |
| textTertiary trên paper | 3.48:1 | Không đủ cho placeholder/chữ phụ thông thường |
| textMuted trên paper | 4.63:1 | Đạt mốc chữ thường với hai màu token này |
| textSecondary trên paper | 4.76:1 | Đạt với hai màu token này |
| ink trên yellow | 9.11:1 | Cặp có độ tương phản tốt |

Các con số là tính từ màu đặc; không tự suy ra cho mọi trường hợp opacity/blending. Cam dùng làm brand trang trí có thể giữ, nhưng caption, tab active, lỗi form và thông tin quan trọng cần semantic token đậm hơn. Quy tắc đối chiếu: [WCAG Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

### F21 — P2 — Hit area, semantics và kích thước chữ chưa đồng nhất

**Theo code:** `lib/screens/journal_view.dart:930`, `lib/screens/login_view.dart:468`, `lib/screens/ai_reflection_view.dart:1264`, `lib/screens/home_shell.dart:85`.

Nút Thêm nhật ký có minHeight 36; toggle đăng nhập/đăng ký là GestureDetector quanh RichText; chip feedback dùng padding nhỏ. Một số icon-only như hiện mật khẩu/đóng chưa có tooltip/label rõ trong code. Ngược lại bottom nav, calendar, cảm xúc và sync notice đã có Semantics tốt ở nhiều nơi.

Header và switcher dùng FittedBox scaleDown có thể làm chữ nhỏ đi khi người dùng tăng cỡ chữ. Không có overflow chưa đồng nghĩa nội dung dễ đọc. RichText tự dựng cũng cần kiểm tra textScaler, không mặc định coi nó tương đương Text.

**Sửa/đạt:** chuẩn hóa vùng bấm theo platform, nút có tên truy cập và trạng thái chọn/disabled, không phụ thuộc emoji/màu để truyền nghĩa; kiểm thử VoiceOver/TalkBack và text lớn thật. Tham khảo [checklist Flutter](https://docs.flutter.dev/ui/accessibility).

### F22 — P2 — Bài “nhìn lại tuần” không được kiểm tra thuộc tuần nào

**Theo code:** `lib/state/mindra_state.dart:1359`, `lib/screens/progress_view.dart:165`.

State giữ một Map weeklyReview có date, nhưng UI chỉ kiểm tra khác null để nói “Bạn đã nhìn lại tuần này rồi”. Sang tuần mới vẫn có thể nhận trạng thái đã hoàn thành từ tuần cũ; không có lịch sử nhiều tuần.

**Sửa/đạt:** key theo tuần và timezone, hiển thị khoảng ngày; lưu lịch sử. Mở vào thứ Hai tuần mới phải mời viết tuần mới, đồng thời vẫn đọc được tuần trước.

### F23 — P2 — Xuất dữ liệu thiếu trường và thiếu phản hồi khi share thất bại

**Theo code:** `lib/screens/settings_view.dart:646`.

JSON có entry cơ bản nhưng bỏ exerciseId, afterEmotionKey, usefulnessRating, easeRating, repeatPreference; không có schemaVersion. Nếu UX gọi đây là nhật ký thì cần nói rõ phạm vi; nếu là bản sao dữ liệu cá nhân thì còn thiếu phản tư, bước nhỏ, review và metadata liên quan. Lệnh share chưa await/catch để phản hồi lỗi.

**Sửa/đạt:** công bố phạm vi export, đầy đủ trường thuộc phạm vi, có version/schema và thông báo khi không tạo/chia sẻ được file. Hủy share không bị coi là lỗi. Test trên iPad với popover origin và file UTF-8 đọc được.

### F24 — P2 — Đổi giờ nhắc thất bại vẫn có thể hiển thị giờ mới

**Theo code:** `lib/state/mindra_state.dart:1340`, `lib/screens/settings_view.dart:145`.

`setReminderTime` gán và notify giờ trước khi schedule thành công. Nếu reschedule thất bại, UI có thể giữ giờ mới trong khi lịch hệ điều hành vẫn cũ. Nhãn lỗi hiện tập trung vào việc cấp quyền, chưa phân biệt lỗi lên lịch.

**Sửa/đạt:** commit giờ sau thành công hoặc rollback; khi bật lại app đối chiếu pending notification. Phân biệt quyền bị từ chối, lỗi scheduling và đã tắt; có đường tới cài đặt hệ thống khi cần.

### F25 — P2 — Công tắc hiển thị vườn đang diễn đạt rộng hơn tác dụng

**Theo code:** `lib/screens/settings_view.dart:473`, `lib/screens/today_view.dart:461`, `lib/screens/personal_space_view.dart:75`.

`gardenVisible` ẩn preview trên Hôm nay nhưng Góc riêng vẫn luôn có mục Khu vườn. Đây có thể là chủ ý sản phẩm; nhãn “Hiển thị Khu vườn Moodi” hiện không chỉ rõ phạm vi.

**Sửa/đạt:** đổi thành “Hiện khu vườn trên Hôm nay”, hoặc thực thi ẩn mọi entry point nếu mục tiêu là tắt toàn bộ lớp vườn. Nội dung setting và kết quả phải khớp.

### F26 — P2 — Một lỗi polling có thể thay cả màn cộng đồng/chat bằng trạng thái lỗi

**Theo code:** `lib/community/community_view.dart:74`, `lib/community/community_view.dart:188`, `lib/community/community_people.dart:657`.

CommunityView giữ bootstrap cũ nhưng khi error khác null lại ưu tiên trả cả trang lỗi. Chat còn xóa `items = []` khi bất kỳ fetch lỗi, bao gồm lỗi mạng tạm thời; lịch sử đang đọc biến mất. Các lỗi mất quyền/đã chặn cần xử lý khác với mất mạng.

**Sửa/đạt:** giữ dữ liệu cũ với banner “chưa cập nhật”, retry không phá vị trí cuộn; chỉ dọn nội dung khi quyền không còn hoặc dữ liệu đã xóa. Kiểm tra lỗi khi tải trang cũ và khi gửi tin riêng.

### F27 — P2 — Thông báo đánh dấu đọc toàn bộ ngay khi mở và gộp lỗi đọc/ghi

**Theo code:** `lib/community/community_notifications.dart:32`.

Sau khi tải danh sách, app gọi `markNotificationsRead` cho toàn bộ; UI vẫn giữ `isRead` cũ trong items. Nếu bước ghi read lỗi, catch chuyển cả màn thành lỗi tải dù danh sách đã về. Người dùng có thể mất tín hiệu chưa đọc của những mục chưa xem.

**Sửa/đạt:** chọn rõ “đã nhìn thấy danh sách” hay “đã mở nội dung”; đồng bộ badge và read state ngay. Lỗi mark-read không che danh sách. Kiểm tra thông báo trỏ tới bài/nhóm đã bị xóa hoặc không còn quyền.

### F28 — P2 — Đăng nhập chưa có đường tự khôi phục khi quên mật khẩu

**Theo code:** `lib/screens/login_view.dart`, `backend/src/auth/auth.controller.ts`.

Không có hành trình Quên mật khẩu trong UI và chưa có endpoint phục hồi tương ứng ở controller được review. Form cũng chưa cấu hình AutofillGroup/autofillHints; điều này làm luồng password manager kém rõ hơn. Nút mắt thiếu lời mô tả cụ thể cho screen reader.

**Sửa/đạt:** thêm phục hồi email với trạng thái gửi/đợi/thử lại thích hợp; autofill và submit bàn phím đúng; phân biệt login/register trong lỗi. Nếu chưa làm backend, nêu giới hạn ở hỗ trợ tài khoản và không tạo nút giả.

## 6. Hoàn thiện và quyết định phạm vi

### F29 — P3 — Polling toàn bộ nhật ký/vườn cần chính sách tải hợp lý

**Theo code:** `lib/repositories/journal_repository.dart:137`, `lib/repositories/garden_repository.dart:106`, `backend/src/entries/entries.service.ts:22`.

Entries và moments polling mỗi 5 giây; findAll entries trả toàn bộ lịch sử. Chưa thấy pause theo lifecycle tại hai stream này. Community/chat đã có một số chặn khi background hoặc route không active.

Đây là rủi ro về pin, data và jank khi lịch sử lớn, chưa phải kết quả đo performance. Nên fetch tức thì rồi refresh theo nhu cầu/resume, phân trang hoặc delta theo revision. Đo với 1.000+ entries, không suy hiệu năng từ 8 entry giả.

### F30 — P3 — Hình ảnh có bản sắc, nhưng mật độ và ngôn ngữ cần bớt công sức đọc

**Nhận định thiết kế:** `today_view.dart`, `practice_view.dart`, `ai_reflection_view.dart`, `core/theme/typography.dart`.

- Hôm nay dành diện tích lớn cho headline, emotion card và các lời dẫn. Nên kiểm tra time-to-first-check-in trước khi thêm nội dung mới. Giữ một CTA chính; trạng thái đã ghi hôm nay nên gọn hơn để tiện ích dễ thấy.
- Tiến trình có nhiều card/tiêu đề. Nên ưu tiên 1–2 quan sát có dữ liệu và một hành động; chi tiết mở rộng sau. Không biến cường độ cao thành “tệ” cho mọi cảm xúc.
- “Suy nghĩ tự động”, “lăng kính”, “tự trắc ẩn”, “tiếp đất” có thể lạ với người mới. Dùng câu hỏi đời thường rồi giải thích thuật ngữ khi cần. Cho người dùng bỏ qua mà không mất cảm giác hoàn thành.
- “Nghỉ 30 giây” hiện là 4 bước có đọc, chọn và ghi; thời gian thực tế chưa đo. Nên tách nghỉ thở thật ngắn khỏi check-in nhiều bước hoặc đổi nhãn theo thời lượng thực tế.
- Body 14, caption 12, micro 11; một số chỗ 9–10. Nên ưu tiên khả năng đọc cho người đang mệt. Hạn chế chữ hoa/kicker dày ở những vùng vốn nhiều nhãn.
- Emoji có thể hợp với cảm xúc nhưng cần giới hạn cho điều khiển hệ thống; hiện trộn Material/Cupertino/emoji. Duy trì một bộ icon theo vai trò và không coi khác biệt rendering emoji trong test là lỗi của app trên thiết bị.

### F31 — P3 — Khóa ứng dụng mới là demo, chưa phải hành trình bảo vệ hoàn chỉnh

**Theo code:** `lib/screens/settings_view.dart:426`, `lib/screens/app_lock_view.dart:24`, `lib/main.dart:40`.

PIN cố định được công bố rõ và setting chỉ hiện debug là lựa chọn tốt. Tuy nhiên nó không lưu cấu hình khóa bền và không có lifecycle relock. Không trình bày demo này như Face ID/PIN thật khi giới thiệu sản phẩm. Nếu làm khóa thật, cần thiết lập/thay PIN, sinh trắc học, timeout background và phục hồi; che preview app switcher là một kiểm tra riêng.

### F32 — P3 — Tài liệu, tên gọi và phạm vi chưa khớp hoàn toàn

**Theo code:** `README.md`, `pubspec.yaml:1`, `lib/main.dart:71`, `lib/state/mindra_state.dart:1226`.

README nói phần lớn settings chưa lưu, nhưng code đã lưu low stimulation/garden/goals/onboarding/AI; README còn liệt kê chế độ khách trong khi login không có nút. Tên repo/package/class Mindra và thương hiệu Moodi cùng tồn tại. Tên nội bộ không tự tạo lỗi UX, nhưng tên hiển thị, bundle display name, notification và export cần thống nhất khi đóng gói.

Cập nhật ma trận tính năng: hoạt động qua UI / chỉ API / debug-only / cần cấu hình provider / chưa có. Tránh dùng ảnh hoặc mô tả demo để khẳng định hành trình chưa nối UI đã hoàn thiện.

## 7. Kết quả render bố cục

Đây là kiểm tra frame đầu tiên của từng trạng thái, với font thật và theme app. Các màn con render riêng chưa mô phỏng toàn bộ container, bàn phím và safe area của route production. Không dùng ma trận này để chứng nhận toàn bộ màn hoặc toàn bộ flow đã đạt accessibility.

| Trạng thái | 390×844, 100% | 320×568, 200% | Ghi chú |
|---|---|---|---|
| Hôm nay | Không overflow | Không overflow | Còn cần kiểm tra text bị scaleDown và focus |
| Góc riêng / Nhật ký | Không overflow | 30 lỗi dọc, khoảng 6–7.2 px mỗi ô | Grid ô ngày có chiều cao không đủ |
| Góc riêng / Khu vườn | Không overflow | Không overflow | Không kết luận hit target hoa đã đạt |
| Khám phá / Tiến trình | Không overflow | Không overflow | Thống kê còn lỗi ngữ nghĩa F07 |
| Khám phá / Thực hành | Không overflow | 1 lỗi ngang, 18 px | Catalog, cần xem thêm các filter |
| Check-in nhanh, chưa chọn | Không overflow | 1 lỗi ngang, 95 px | Cần test cả full check-in và bàn phím |
| Cài đặt | Không overflow | 4 lỗi ngang, tối đa 223 px | Header card và nhóm điều khiển |
| Đăng nhập | Không overflow | Không overflow | Chưa test register/keyboard ở ma trận này |
| Onboarding trang đầu | Không overflow | 1 lỗi dưới, 369 px | Hai trang còn lại cần test riêng |
| Pause bước đầu | Không overflow | 1 lỗi ngang, 47 px | Chưa chứng nhận 3 bước tiếp theo |
| Phản tư có cache | Không overflow | 1 lỗi ngang, 48 px | Phản tư safety/loading cần kiểm tra riêng |
| Session giới thiệu | Không overflow | 1 lỗi dưới, khoảng 305 px | Nội dung thật cần scroll khi chữ lớn |

Tổng cộng **8/12 trạng thái** có ít nhất một overflow ở cấu hình chữ lớn. 30 lỗi ô ngày là nhiều instance của cùng một nhóm nguyên nhân, không phải 30 finding độc lập.

Probe kết thúc 30 case passed vì có case cố ý **xác nhận lỗi hiện hữu** và case render chỉ **thu thập diagnostics**. “Passed” của probe không mang nghĩa 24 cấu hình render đều tốt.


## 8. Review từng hành trình thực tế

### 8.1 Mở app, onboarding và đăng nhập

Điểm tốt: có splash chờ restore/preferences để tránh chớp onboarding; onboarding chỉ 3 trang; form đăng ký có xác nhận password, tên tùy chọn và loading state; provider được kiểm tra cấu hình; logout tạo lại MaterialApp key theo session để tránh giữ route của người trước.

Cần sửa: F10, F13, F28. Onboarding đọc khá dài so với tác vụ check-in; có thể cho xem giá trị trước rồi mới thiết lập mục tiêu. Khi restore gặp mạng lỗi, token có thể còn nhưng người dùng thấy login; chưa có chế độ mở nội dung offline vì thiếu kho journal bền. Cần giữ nguyên khác biệt “phiên hết hạn” và “chưa kết nối được”, tránh khiến người dùng nghĩ tài khoản biến mất.

### 8.2 Check-in nhanh

Luồng hiện tại: chọn một cảm xúc → mở sheet → cường độ → lưu → entry thêm ngay vào state → request chạy nền → sheet đóng → HomeShell có thể mở lời mời giữ hoa.

Điểm tốt: không bắt viết; nút lưu disabled trước lựa chọn; có sync notice, có retry; không auto-plant mọi entry. Cần sửa F01/F03/F09/F18. Lời mời hoa không nên che mất trạng thái chưa lưu bền; tiêu đề “Đã lưu check-in” cần phân biệt đang chờ server. Giữ một đường rõ tới nhật ký và bỏ qua lời mời mà không thấy mình làm chưa đủ.

### 8.3 Check-in đầy đủ và phản tư

Luồng hiện tại: cảm xúc/cường độ → trigger tùy chọn → situation/thought/response → lưu + gợi ý hoặc chỉ lưu. Phản tư chờ tối đa 20 giây rồi dùng mẫu local; nguồn AI/template được phân biệt trong nội dung; có luồng safety riêng.

Điểm tốt: có nguồn rõ hơn, có local fallback và người dùng được nói “chỉ giữ điều phù hợp”. Cần sửa F02/F06/F13/F14/F17. Tối đa 20 giây vẫn dài với một tác vụ cảm xúc; nên có đường “xem nhật ký trong lúc chờ” hoặc xem mẫu ngay với thao tác chọn dùng AI. Hiện request có thể tiếp tục sau timeout UI, nên kết quả mở lại có thể khác; cần giải thích và bảo vệ chỉnh sửa trước phản hồi muộn.

### 8.4 Nhật ký, ghi bù, chỉnh sửa và xóa

Điểm tốt: nhiều entry cùng ngày được hỗ trợ; chặn ngày tương lai; ngày có semantics; xóa có confirm và chờ API, lỗi không giả báo thành công; giữ hoa và xóa entry được diễn đạt khác nhau.

Cần sửa F10/F12/F17/F18. Thêm màn chi tiết entry cho dữ liệu đầy đủ. Người dùng nên đi từ thống kê hoặc hoa tới đúng entry/ngày, thay vì callback chỉ mở tab Nhật ký mặc định hôm nay. Xóa hoa không xóa entry là quy ước tốt cần giữ; xóa entry cần lifecycle phản tư rõ theo F08.

### 8.5 Khu vườn

Điểm tốt: hình ảnh khác biệt; giải thích hoa tương ứng ghi chép muốn giữ; có danh sách thay thế việc chạm từng hoa; có tháng; chống trồng trùng đang chạy bằng `_pendingPlants`.

Cần làm rõ: màu/thời tiết biểu thị điều gì, nhất là khi dữ liệu cảm xúc chưa chắc chắn; không suy diễn người dùng đang “tốt hơn” chỉ từ số hoa. Setting F25 cần đúng phạm vi. Kiểm tra actual hit target hoa trên thiết bị; người dùng screen reader phải tìm được entry qua danh sách. Vườn chung chưa có đường UI hoàn chỉnh; không đưa vào checklist luồng đã đạt.

### 8.6 Nghỉ 30 giây

Luồng hiện tại gồm 4 bước; animation thở được start ngay init, trước khi bước thở hiển thị. Vì vậy khi đọc/chọn cơ thể lâu, một phần hoặc toàn bộ nhịp có thể chạy ngoài màn. Cần bắt đầu khi bước thở được mở, dừng khi rời bước và xử lý background.

F04 là lỗi dữ liệu quan trọng nhất. Probe nhánh “Viết ra những suy nghĩ này” vẫn mở được CheckinView và giữ HomeShell, **chưa tái hiện crash từ double-pop**. Tuy nhiên `_savePauseModeEntry` gọi onClose rồi callback chuyển tiếp lại pop ở HomeShell, nên nên gom quyền sở hữu đóng/mở vào một nơi. Không ghi double-pop là một crash đã được xác nhận.

### 8.7 Vò giấy xả giận

Điểm tốt nổi bật: nội dung được giữ như nghi thức tạm, không tự nhập journal hoặc garden; có PopScope, xác nhận trước mất nháp, nút thay thế gesture và hoàn tác trong khoảng ngắn. `_quiet` có đọc cả giảm kích thích của app và disableAnimations của hệ thống. Đây là mẫu có thể tái sử dụng cho check-in.

Chưa kiểm chứng trên thiết bị: xung đột kéo sheet/giấy, hiệu ứng khi app background, font emoji và độ mượt stage bitmap. Cần test mốc hết thời gian hoàn tác, không nhầm “thả giấy” với đã xóa mọi dữ liệu journal của tài khoản.

### 8.8 Thực hành và cảm xúc sau bài tập

Điểm tốt: có mục đích trước khi bắt đầu, cho dừng, có các loại thở/steps/write và sau hoàn thành có thể chỉ chọn Xong. Cần sửa F05/F15/F16/F18/F19. Không nên tuyên bố đã dành đúng “2 phút” nếu người dùng bấm qua các bước trong vài giây; tách thời lượng dự kiến và elapsed thật. Nên có quay lại bước trước, dừng/tiếp tục cho bài có timer và không ép trạng thái tích cực sau khi hoàn thành.

### 8.9 Tiến trình, nhịp lặp, bưu thiếp và mục tiêu

Điểm tốt: chart có tooltip, semantics và phân biệt ngày không ghi; nhịp lặp có thông báo tương quan không suy nguyên nhân; chi tiết thống kê được đặt trong phần mở rộng để giảm tải.

Cần sửa F07/F15/F22. Thống nhất rõ từng phạm vi: tuần lịch, rolling 7/30 ngày, toàn bộ lịch sử. Trong ảnh test, card 4/7 ngày và chart 5/7 ngày có thể cùng đúng vì dùng cửa sổ khác nhau, nhưng phải ghi nhãn để người dùng hiểu. Cường độ trung bình gộp vui mạnh và buồn mạnh không phải thước đo sức khỏe hay tiến bộ; thêm giải thích hoặc cho lọc theo cảm xúc. Huy hiệu nên khuyến khích hiện diện, không phạt mất streak.

Bước nhỏ và weekly review hiện có lưu local theo user; chưa phải đồng bộ đa thiết bị. Giao diện cần nói đúng phạm vi khi người dùng đổi máy hoặc xuất dữ liệu.

### 8.10 Cộng đồng, bạn bè, nhóm và chat

Điểm tốt: hồ sơ cộng đồng tách nhật ký riêng; composer hiển thị đích đăng; requestId ổn định cho retry; có bảo vệ bỏ nháp; filter feed; friend-code thay tìm email; chặn/báo cáo; kiểm soát response tới muộn theo session; group invite có nhánh quản lý; chat có kiểm tra foreground và polling.

Các test hiện có bao phủ khá nhiều failure/permission/idempotency. Tuy vậy đó là test với fake API, chưa thay cho hai tài khoản thật trên hai thiết bị.

Cần sửa F26/F27 và F12. Hãy test hành trình: A mời B → B nhận → vào nhóm → đăng → A phản hồi → B nhận thông báo → deep-link đúng nội dung. Kiểm tra chủ nhóm rời/xóa nhóm, bỏ kết bạn khi đang chat, chặn trong lúc request đang chạy, báo cáo bị retry và bài đã xóa khi mở notification. Không coi polling 6 giây là realtime; có thể diễn đạt nhẹ thời điểm cập nhật, tránh nhãn online/seen nếu dữ liệu không đáp ứng.

### 8.11 Cài đặt, xuất, xóa và đăng xuất

Điểm tốt: settings thực sự lắng nghe state nên toggle cập nhật; có nhắc quyền khi bật notification; dữ liệu export dùng share sheet thay clipboard; UI xóa nói rõ không bao gồm community/message; một số preference đã có lưu bền.

Cần sửa F08/F11/F13/F23/F24/F25. Hai nơi logout đang xử lý khác: settings await/catch, profile modal dùng unawaited; nên cùng một đường handling để lỗi không im lặng. Chưa có hành trình xóa tài khoản hoàn chỉnh trong UI/controller đã review; cần quyết định scope riêng, không đổi nút xóa nhật ký thành xóa tài khoản khi backend chưa hỗ trợ.

## 9. Thứ tự triển khai đề xuất

### Đợt 1 — Làm dữ liệu và hành trình cốt lõi đáng tin

1. F01, F02, F05: lỗi chọn lần đầu, context điều hướng và set rỗng.
2. F04, F07: ngừng tự tạo dữ liệu và ngừng gắn lịch sử thành tuần hiện tại.
3. F03, F09: local persistence/outbox và thứ tự ghi.
4. F06, F08: version phản tư và lifecycle khi sửa/xóa.
5. F10: sửa chữ lớn cho onboarding, check-in, lịch và session.

### Đợt 2 — Hoàn thiện vòng sử dụng hằng ngày

1. Loading/error/empty/read-sync đúng trạng thái; giữ tab/scroll/filter.
2. Đọc/sửa đủ entry, lưu nháp, practice session riêng và before/after thật.
3. AI opt-in đúng điểm sử dụng, feedback/chỉnh sửa lưu bền.
4. Weekly review theo tuần, export đầy đủ, reminder rollback và setting vườn đúng nghĩa.

### Đợt 3 — Hoàn thiện accessibility và kiểm tra đa người dùng

1. Semantic color, touch target, screen reader, Reduce Motion từ OS.
2. Community giữ dữ liệu khi lỗi tạm, notification read state và deep-link.
3. Forgot password, phạm vi xóa tài khoản, tải dữ liệu lớn và lifecycle.
4. Chốt visual polish, độ dài nội dung, nhãn thời lượng và tài liệu tính năng.

Không cần làm lại toàn bộ phong cách giao diện trước các đợt trên. Nên giữ nền giấy, bộ mặt cảm xúc và ý tưởng vườn, đồng thời giảm phần đọc không cần thiết trên đường check-in.

## 10. Tiêu chí để lần review sau có thể kết luận tốt hơn

- Chạy checklist [kiểm thử luồng thực tế](uiux-flow-test-matrix-2026-11-06.md), ghi Pass/Fail/Blocked theo môi trường.
- Có ít nhất một lần chạy end-to-end trên iOS và Android với backend thật và hai tài khoản test; không dùng dữ liệu cá nhân thật cho thử nghiệm.
- Force-close khi entry pending vẫn phục hồi, và request đảo thứ tự không mất bản sửa cuối.
- Nội dung journal/reflection/practice sau sửa, xóa, logout và restart khớp với kỳ vọng đã mô tả.
- Chữ 200%, màn hẹp, bàn phím, screen reader và reduced motion thao tác được ở toàn bộ luồng quan trọng.
- Người mới tự hoàn thành các tác vụ: check-in đầu tiên, đọc lại/sửa, thực hành rồi phản hồi, tìm cài đặt riêng tư. Ghi thời gian, chỗ dừng và câu hỏi thật của người dùng; không chỉ hỏi họ “có thích giao diện không”.

## 11. Tài liệu đối chiếu

- [Flutter accessibility checklist](https://docs.flutter.dev/ui/accessibility): kiểm tra screen reader, scale factor, contrast và target tương tác.
- [WCAG Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html): dùng làm tham chiếu tính tương phản màu, không xem review này là chứng nhận tuân thủ cho app native.
- Skill dùng trong review: `ui-ux-pro-max`, tập trung Flutter/accessibility/state; kết luận cụ thể trong báo cáo dựa trên code và kiểm tra của dự án.
