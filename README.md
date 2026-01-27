# HỆ THỐNG QUẢN LÝ CLB PICKLEBALL "VỢT THỦ PHỐ NÚI" (PCM)

**Bài Kiểm Tra 02 (Nâng Cao - Mobile)**
*   **Sinh viên**: Lê Anh Sơn
*   **MSSV**: 1771020591
*   **Môn học**: Lập trình Mobile với Flutter

---

## 📖 Giới thiệu

PCM (Pickleball Club Management) là ứng dụng di động trọn gói dành cho CLB Pickleball, giúp quản lý hội viên, đặt sân, tổ chức giải đấu và quản lý tài chính minh bạch. 
Hệ thống bao gồm **Mobile App** (Flutter) dành cho người dùng/admin và **Backend API** (ASP.NET Core) xử lý nghiệp vụ & real-time.

## 🚀 Tính năng nổi bật

### 1. Quản lý Hội viên & Ví (Smart Operations)
*   **Hạng thành viên (Tier)**: Tự động xét hạng Đồng, Bạc, Vàng, Kim Cương dựa trên chi tiêu.
*   **Ví điện tử**: Nạp tiền, Thanh toán tự động, Lịch sử giao dịch minh bạch.
*   **Real-time Notifications**: Thông báo biến động số dư, lịch đặt sân tức thì (SignalR).

### 2. Đặt sân thông minh (Smart Booking)
*   **Đặt lịch**: Xem lịch trống trực quan, chọn giờ đăt sân nhanh chóng.
*   **Recurring Booking (VIP)**: Đặt lịch định kỳ hàng tuần cho thành viên VIP/Admin.
*   **Check trùng**: Hệ thống tự động ngăn chặn trùng giờ.

### 3. Giải đấu chuyên nghiệp (Pro Tournaments)
*   **Quản lý giải**: Tạo giải đấu, Cấu hình thể thức (Vòng tròn/Loại trực tiếp).
*   **Auto-Scheduler**: Tự động bốc thăm và xếp lịch thi đấu.
*   **Bracket Visualizer**: Xem cây thi đấu trực quan.
*   **Cập nhật tỉ số**: Trọng tài cập nhật kết quả trận đấu, hệ thống tự động tính người thắng.

### 4. Hệ thống (System)
*   **Background Services**: Tự động hủy booking chưa thanh toán, Tự động nhắc lịch.
*   **Admin Dashboard**: Thống kê doanh thu, quản lý sân bãi.

---

## 🛠️ Công nghệ sử dụng

*   **Frontend (Mobile)**: Flutter, Provider (State Management), Dio (API), TableCalendar, FlChart.
*   **Backend**: ASP.NET Core Web API, Entity Framework Core, SQL Server.
*   **Real-time**: SignalR.
*   **Services**: BackgroundService (Hosted Service).

---

## ⚙️ Hướng dẫn cài đặt & Chạy

### 1. Backend (ASP.NET Core)

Yêu cầu: .NET SDK 8.0 trở lên, SQL Server.

```bash
# Di chuyển vào thư mục Backend
cd Backend/PCM_Backend

# Cấu hình ConnectionString trong appsettings.json nếu cần (mặc định đùng LocalDB hoặc SQL Express)

# Chạy Backend
dotnet run
```
*   Server sẽ chạy tại: `http://localhost:5220`
*   Swagger UI: `http://localhost:5220/swagger`

### 2. Mobile App (Flutter)

Yêu cầu: Flutter SDK.

```bash
# Di chuyển vào thư mục Mobile
cd Mobile

# Cài đặt thư viện
flutter pub get

# Chạy ứng dụng (Windows hoặc Emulator)
flutter run
```

---

## 🔐 Tài khoản Demo (Data Seeding)

Hệ thống đã có sẵn dữ liệu mẫu (Seeded Data) để chấm bài:

| Role | Username | Password | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin` | `Password123!` | Full quyền, xem Dashboard doanh thu |
| **Treasurer**| `treasurer`| `Password123!` | Duyệt tiền nạp |
| **Member** | `member1` | `Password123!` | Hạng Standard |
| **VIP** | `vp_gold` | `Password123!` | Hạng Gold (Test đặt sân định kỳ) |

---

## 📸 Cấu trúc thư mục

```
📦 MOBILE_FLUTTER_1771020591_LEANHSON
 ┣ 📂 Backend
 ┃ ┗ 📂 PCM_Backend       # ASP.NET Core Web API Project
 ┣ 📂 Mobile
 ┃ ┣ 📂 lib
 ┃ ┃ ┣ 📂 screens         # UI Screens (Booking, Tournament, Wallet...)
 ┃ ┃ ┣ 📂 services        # API Services, SignalR
 ┃ ┃ ┗ 📂 providers       # State Management
 ┃ ┗ 📄 pubspec.yaml
 ┗ 📄 bai_kiem_tra.txt    # Đề bài
```

---
*Generated for Assignment Submission - Jan 2026*
