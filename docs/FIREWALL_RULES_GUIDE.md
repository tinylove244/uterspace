# Hướng Dẫn Bật / Tắt Tường Lửa (Firewall) Cho Nhóm Test Local

Tài liệu này lưu lại các câu lệnh PowerShell (chạy bằng quyền **Run as Administrator**) để bạn chủ động **MỞ** khi làm việc nhóm và **KHÓA** lại sau khi hoàn thành kiểm thử.

---

## 🟢 1. KHI BẮT ĐẦU TEST (MỞ KHÓA)
> **Mục đích**: Cho phép các máy tính/điện thoại khác trong cùng mạng Wi-Fi truy cập vào Tomcat (`http://<IP_MÁY_BẠN>:8080/uterspace`).

Mở **PowerShell (Run as Administrator)** và chạy các lệnh sau:

```powershell
# 1. Mở cổng 8080 TCP cho Tomcat
New-NetFirewallRule -DisplayName "Tomcat 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow

# 2. Cho phép tiến trình Java nhận kết nối trên mọi loại mạng
Get-NetFirewallRule | Where-Object { ($_.DisplayName -like "*Java*" -or $_.DisplayName -eq "java") -and $_.Action -eq "Block" } | Set-NetFirewallRule -Action Allow
```

*(Lưu ý: Đảm bảo Wi-Fi đang kết nối đã được chuyển sang chế độ **Private network** trong Windows Settings).*

---

## 🔴 2. KHI TEST XONG (KHÓA LẠI)
> **Mục đích**: Thu hồi quyền truy cập từ mạng ngoài vào máy bạn, bảo mật tối đa khi mang laptop ra ngoài quán cafe, nơi công cộng.

Mở **PowerShell (Run as Administrator)** và chạy các lệnh sau:

```powershell
# 1. Xóa luật mở cổng Tomcat 8080
Remove-NetFirewallRule -DisplayName "Tomcat 8080" -ErrorAction SilentlyContinue

# 2. Khóa lại kết nối Java trên mạng Public (trả về mặc định của Windows)
Get-NetFirewallRule | Where-Object { ($_.DisplayName -like "*Java*" -or $_.DisplayName -eq "java") -and $_.Profile -like "*Public*" } | Set-NetFirewallRule -Action Block
```

---

## 🔍 3. LỆNH KIỂM TRA TRẠNG THÁI HIỆN TẠI (TÙY CHỌN)
Nếu muốn kiểm tra xem cổng 8080 và Java đang Mở hay Khóa, chạy:

```powershell
# Kiểm tra cổng 8080
Get-NetFirewallRule -DisplayName "Tomcat 8080" -ErrorAction SilentlyContinue | Select-Object DisplayName, Enabled, Action

# Kiểm tra các rule của Java
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*Java*" -or $_.DisplayName -eq "java" } | Select-Object DisplayName, Action, Profile
```
