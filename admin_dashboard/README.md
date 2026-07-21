# Smart Expense Admin Dashboard

Dashboard web này dùng chung Firebase project với app Flutter để quản lý user và xem report từ Firestore.

## Chạy local

```bash
cd admin_dashboard
npm install
npm run dev
```

Mở link Vite hiển thị trong terminal, thường là `http://localhost:5173`.

## Tạo tài khoản admin lần đầu

1. Vào Firebase Console > Authentication > Users.
2. Tạo hoặc chọn một tài khoản email/password để dùng làm admin.
3. Vào Cloud Firestore > collection `users` > document có ID trùng UID của tài khoản đó.
4. Thêm hoặc sửa các field:
   - `role`: `admin`
   - `status`: `active`

Nếu document user chưa tồn tại, hãy đăng nhập tài khoản đó bằng app Flutter một lần để app tự tạo document, rồi quay lại gán `role: admin`.

## Deploy Firestore Rules

Dashboard cần rules mới để admin đọc được tất cả user và collection con:

```bash
firebase deploy --only firestore:rules
```

Nếu chưa đăng nhập Firebase CLI:

```bash
firebase login
```

## Build và deploy dashboard

```bash
cd admin_dashboard
npm run build
cd ..
firebase deploy --only hosting
```

Firebase Hosting đã được cấu hình trong `firebase.json` để lấy source từ `admin_dashboard/dist`.
