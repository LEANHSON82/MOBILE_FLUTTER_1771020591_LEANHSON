# MOBILE_FLUTTER_1771020591_LEANHSON

Hệ thống Quản lý CLB Pickleball "Vợt Thủ Phố Núi" (PCM)

## Cấu trúc dự án
- **Backend**: ASP.NET Core Web API (Folder `Backend/PCM_Backend`)
- **Mobile**: Flutter App (Folder `Mobile`)

## Hướng dẫn chạy

### 1. Backend (ASP.NET Core)
Yêu cầu: .NET SDK 8.0 trở lên.
**Lưu ý:** Backend hiện tại đang sử dụng **InMemory Database** nên **KHÔNG CẦN SQL Server**. Dữ liệu mẫu sẽ tự động được tạo mỗi khi chạy.

1. Mở terminal tại `Backend/PCM_Backend`.
2. Chạy dự án:
   ```bash
   dotnet run
   ```
   Backend sẽ chạy tại `https://localhost:7108`.

### 2. Mobile App (Flutter)
Yêu cầu: Flutter SDK.

1. Mở terminal tại `Mobile`.
2. Cài đặt dependencies:
   ```bash
   flutter pub get
   ```
3. Chạy ứng dụng (trên Emulator Android):
   ```bash
   flutter run
   ```

**Lưu ý:**
- API URL trong App được cấu hình là `https://10.0.2.2:7108/api/` (dành cho Android Emulator). Nếu chạy trên iOS hoặc thiết bị thật, vui lòng đổi IP trong `Mobile/lib/services/api_service.dart`.

## Tài khoản Test (Tự động tạo)
Hệ thống đã tự động tạo sẵn các tài khoản sau để test:

| Role | Username | Password | Chức năng |
|---|---|---|---|
| **Admin** | `admin` | `Password123!` | Duyệt nạp tiền, quản lý giải đấu |
| **Member** | `member1` | `Password123!` | Đặt sân, nạp tiền, xem lịch |
| **Member** | `member2` | `Password123!` | ... |

*(Có tổng cộng 20 member từ `member1` đến `member20`)*
