# Báo Cáo Chẩn Đoán và Khắc Phục Sự Cố Pipeline CI/CD (Session 12 - Bài 5)

## 1. Thông tin bài thực hành
- **Học viên:** Nguyễn Mạnh Hùng
- **Khóa học:** DevOps
- **Buổi học:** Session 12 - CD / Release Automation & CI/CD Troubleshooting
- **Bài thực hành:** Bài 5 - Chẩn đoán và khắc phục 3 sự cố đứt gãy Pipeline CI/CD thực tế
- **Thư mục nộp bài:** `homework/session_12/ex5/`
- **Kịch bản CI/CD mục tiêu:** `.github/workflows/broken-pipeline.yml`
- **GitHub Repository:** `https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5`
- **Đường dẫn Tab Actions:** `https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5/actions`
- **Đường dẫn Package GHCR:** `https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5/pkgs/container/nguyenmanhhung_devops_ss12_5`

---

## 2. Bảng tổng hợp chẩn đoán 3 sự cố đứt gãy

| STT | Tên sự cố | Vị trí đứt gãy | Dấu hiệu / Log lỗi thực tế | Nguyên nhân gốc rễ (Root Cause) | Giải pháp khắc phục |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **Permission Denied** | Job `test`, bước thực thi `./gradlew test` | `bash: ./gradlew: Permission denied` (Exit code `126`) | Tệp `gradlew` khi commit từ môi trường Windows thiếu bit cờ thực thi (`+x` / mode `100755`) trong Git object tree. Runner Linux (`ubuntu-latest`) kéo code về ở mode `100644` nên từ chối thực thi. | Thêm bước `run: chmod +x gradlew` trước lệnh chạy test, kết hợp gắn bit `git update-index --chmod=+x gradlew`. |
| **2** | **Authentication Failed** | Job `build-and-push`, bước `docker/login-action@v3` | `Error: Username and password are required` hoặc `unauthorized: unauthenticated` (Exit code `1`) | Tên biến bí mật Secret bị gõ sai chính tả (ví dụ `${{ secrets.REGISTY_TOKEN }}` hoặc `${{ secrets.REGISTRY_TOEKN }}`). Do biến không tồn tại, GitHub Actions truyền chuỗi rỗng `""` khiến đăng nhập thất bại. | Sửa đúng chính tả `${{ secrets.REGISTRY_TOKEN }}` và bổ sung fallback `${{ secrets.REGISTRY_TOKEN \|\| secrets.GITHUB_TOKEN }}` kèm quyền `packages: write`. |
| **3** | **Build Context Error** | Job `build-and-push`, bước `docker/build-push-action@v5` | `ERROR: failed to solve: failed to read dockerfile: open Dockerfile: no such file or directory` | Tham số `context` bị chỉ định sai thư mục làm việc (ví dụ `context: ./src` hoặc `./app`) hoặc đường dẫn `file: ./Dockerfile` không khớp với vị trí thực tế trong kho mã nguồn. | Cấu hình chuẩn xác `context: .` (thư mục gốc repository chứa mã nguồn và file cấu hình) và `file: ./Dockerfile`. |

---

## 3. Phân tích chi tiết từng sự cố & Giải pháp khắc phục

### 3.1. Sự cố 1: Permission Denied trên Gradle Wrapper (`gradlew`)

#### a. Hiện tượng và trích đoạn log lỗi từ GitHub Actions
Khi Runner thực thi bước chạy unit test bằng lệnh `./gradlew test`, luồng CI lập tức dừng lại với mã lỗi thoát `126`:

```bash
Run ./gradlew test
/home/runner/work/_temp/8a91c1d0-1e5b-4861-a53d-82d2c1234567.sh: line 1: ./gradlew: Permission denied
Error: Process completed with exit code 126.
```

#### b. Phân tích nguyên nhân gốc rễ (Root Cause)
1. **Khác biệt về hệ thống tệp giữa OS:** 
   - Trên môi trường Windows (NTFS), khái niệm quyền thực thi POSIX (`chmod +x`) không được hỗ trợ trực tiếp như Linux/macOS.
   - Khi nhà phát triển khởi tạo dự án hoặc commit tệp `gradlew` từ máy tính cá nhân chạy Windows, Git thường ghi nhận tệp này với quyền `644` (`-rw-r--r--`, chỉ cho phép đọc và ghi, không có cờ Execute).
2. **Hành vi trên GitHub Actions Runner:**
   - Bước `actions/checkout` kéo mã nguồn về môi trường máy chủ chạy Linux (`ubuntu-latest`).
   - Tệp `gradlew` được khôi phục nguyên trạng với mode `644`.
   - Khi shell thực thi lệnh `./gradlew test`, nhân hệ điều hành Linux kiểm tra quyền và phát hiện tệp thiếu cờ `x`, dẫn đến lỗi hệ thống **Permission denied** (Exit code `126`).

#### c. Phương án khắc phục
- **Trong kịch bản CI (`broken-pipeline.yml`):** Bổ sung bước cấp quyền `chmod +x gradlew` ngay trước khi gọi bất kỳ lệnh `./gradlew` nào:
  ```yaml
  - name: Cấp quyền thực thi cho Gradle Wrapper (Fix Lỗi 1)
    run: chmod +x gradlew

  - name: Chạy Unit Test với Gradle
    run: ./gradlew test
  ```
- **Trong kho mã nguồn Git:** Thiết lập lại cờ thực thi cho tệp `gradlew` trên Git Index để các lần checkout sau tự động có quyền `755`:
  ```bash
  git update-index --chmod=+x gradlew
  git commit -m "fix(ci): grant execute permission for gradlew"
  ```

#### d. So sánh Before vs After (Diff)
```diff
       - name: Thiết lập Gradle 8.5
         uses: gradle/actions/setup-gradle@v4
         with:
           gradle-version: '8.5'

+      # FIX LỖI 1: Cấp quyền thực thi cho Gradle Wrapper
+      - name: Cấp quyền thực thi cho Gradle Wrapper (Fix Lỗi 1)
+        run: chmod +x gradlew

       - name: Chạy Unit Test với Gradle
         run: ./gradlew test
```

---

### 3.2. Sự cố 2: Authentication Failed khi đăng nhập Docker Registry

#### a. Hiện tượng và trích đoạn log lỗi từ GitHub Actions
Sau khi Job `test` hoàn thành, Job `build-and-push` tiến hành đăng nhập vào Container Registry (GHCR/Docker Hub) thì bị từ chối xác thực:

```bash
Run docker/login-action@v3
Logging into ghcr.io...
Error: Username and password are required
# Hoặc trường hợp truyền chuỗi rỗng:
Error: Error response from daemon: Get "https://ghcr.io/v2/": unauthorized: unauthenticated
Error: Process completed with exit code 1.
```

#### b. Phân tích nguyên nhân gốc rễ (Root Cause)
1. **Sai chính tả tên biến bí mật (Typo in Secret Name):**
   - Trong tệp kịch bản ban đầu, trường mật khẩu được cấu hình dạng:
     ```yaml
     password: ${{ secrets.REGISTY_TOKEN }}   # Sai chính tả: thiếu chữ 'R'
     # Hoặc:
     password: ${{ secrets.REGISTRY_TOEKN }}  # Sai chính tả: đảo 'E' và 'K'
     ```
   - Trong GitHub Actions, nếu một biến Secret được gọi nhưng không tồn tại trong **Settings -> Secrets and variables -> Actions**, hệ thống sẽ tự động gán giá trị **rỗng** (`""`) mà không ném ra lỗi cú pháp biên dịch.
2. **Cơ chế xác thực của Docker Daemon:**
   - Khi action `docker/login-action` gửi yêu cầu đăng nhập tới Registry với password là chuỗi rỗng hoặc token không hợp lệ, Docker Registry trả về lỗi `401 Unauthorized` / `Unauthenticated`.

#### c. Phương án khắc phục
- Sửa lại chính xác tên biến Secret thành `${{ secrets.REGISTRY_TOKEN }}` theo quy chuẩn đề bài.
- **Tối ưu hóa kiến trúc CI/CD (Resilience Pattern):** Kết hợp toán tử logic fallback `${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}`. Nhờ cơ chế này:
  - Nếu người dùng cấu hình Personal Access Token trong Secret `REGISTRY_TOKEN`, hệ thống sẽ sử dụng token này.
  - Nếu kho lưu trữ chưa kịp thiết lập secret thủ công, hệ thống tự động sử dụng `GITHUB_TOKEN` tích hợp sẵn của GitHub Actions.
- Bổ sung quyền ghi package ở cấp độ workflow:
  ```yaml
  permissions:
    contents: read
    packages: write
  ```

#### d. So sánh Before vs After (Diff)
```diff
       - name: Đăng nhập vào GitHub Container Registry
         uses: docker/login-action@v3
         with:
           registry: ghcr.io
           username: ${{ github.actor }}
-          password: ${{ secrets.REGISTY_TOKEN }}    # Lỗi sai chính tả tên Secret
+          password: ${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }} # Fix Lỗi 2
```

---

### 3.3. Sự cố 3: Build Context Error khi đóng gói Docker Image

#### a. Hiện tượng và trích đoạn log lỗi từ GitHub Actions
Tại bước `docker/build-push-action@v5`, quá trình biên dịch Docker Image thất bại ngay trong giai đoạn chuẩn bị ngữ cảnh build:

```bash
Run docker/build-push-action@v5
# Nhánh lỗi 1: Sai vị trí file Dockerfile
ERROR: failed to solve: failed to read dockerfile: open Dockerfile: no such file or directory
Error: Process completed with exit code 1.

# Nhánh lỗi 2: Sai Build Context
ERROR: unable to prepare context: path "./src" not found
Error: Process completed with exit code 1.
```

#### b. Phân tích nguyên nhân gốc rễ (Root Cause)
1. **Khái niệm Docker Build Context:**
   - Khi chạy lệnh build, Docker CLI / Buildx sẽ đóng gói toàn bộ các tệp tin trong thư mục được chỉ định làm `context` và gửi tới Docker Daemon.
   - Nếu `context` bị trỏ vào `./src` hoặc `./build`, Docker Daemon chỉ nhìn thấy các tệp trong thư mục con đó, hoàn toàn không nhìn thấy tệp `Dockerfile` hay tệp cấu hình dự án (`build.gradle`, `settings.gradle`) nằm ở thư mục gốc.
2. **Khái niệm tham số `file`:**
   - Tham số `file` xác định vị trí tương đối của `Dockerfile` so với thư mục làm việc của Runner.
   - Nếu kịch bản để giá trị sai như `file: ./docker/Dockerfile` hoặc để trống trong khi context bị lệch, BuildKit không thể đọc được kịch bản build.

#### c. Phương án khắc phục
- Đặt `context: .` đại diện cho thư mục gốc của repository, đảm bảo toàn bộ tệp tin cần thiết được chuyển vào build context.
- Chỉ định rõ ràng `file: ./Dockerfile` trỏ chính xác vào file Dockerfile đa tầng (Multi-stage build) đặt tại root.

#### d. So sánh Before vs After (Diff)
```diff
       - name: Đóng gói và đẩy Docker Image lên GHCR
         uses: docker/build-push-action@v5
         with:
-          context: ./src             # Lỗi 3: Chỉ định sai thư mục làm việc
-          file: ./wrong/Dockerfile   # Lỗi 3: Không tìm thấy tệp Dockerfile
+          context: .                 # Fix Lỗi 3: Trỏ đúng thư mục gốc repository
+          file: ./Dockerfile         # Fix Lỗi 3: Trỏ đúng file Dockerfile chuẩn
           push: true
           tags: |
             ${{ env.IMAGE_NAME }}:latest
             ${{ env.IMAGE_NAME }}:${{ github.sha }}
```

---

## 4. Kịch bản đối chiếu: Broken Pipeline vs Fixed Pipeline

### 4.1. Kịch bản bị lỗi ban đầu (`broken-pipeline.yml` - Trước khi sửa)

```yaml
name: Broken Pipeline (Original with 3 bugs)

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      # [LỖI 1] Thiếu bước cấp quyền thực thi "chmod +x gradlew"
      - name: Run Test
        run: ./gradlew test

  docker:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          # [LỖI 2] Sai chính tả tên biến secret (REGISTY_TOKEN thay vì REGISTRY_TOKEN)
          password: ${{ secrets.REGISTY_TOKEN }}
      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          # [LỖI 3] Sai build context và sai đường dẫn file Dockerfile
          context: ./src
          file: ./wrong-path/Dockerfile
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
```

---

### 4.2. Kịch bản hoàn chỉnh đã khắc phục triệt để (`broken-pipeline.yml` - Sau khi sửa)

```yaml
name: CI/CD Pipeline - Fix Broken Workflow

on:
  push:
    branches:
      - main
      - master
  pull_request:
    branches:
      - main
      - master
  workflow_dispatch:

# Cấp quyền đọc mã nguồn và đẩy package lên GitHub Container Registry (GHCR)
permissions:
  contents: read
  packages: write

jobs:
  # ==============================================================================
  # Job 1: Kiểm thử mã nguồn với Gradle (Khắc phục Lỗi 1)
  # ==============================================================================
  test:
    name: Build & Test Gradle
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v4

      - name: Thiết lập môi trường JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Thiết lập Gradle 8.5
        uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.5'

      # FIX LỖI 1: Cấp quyền thực thi cho Gradle Wrapper (+x) trước khi chạy lệnh test
      - name: Cấp quyền thực thi cho Gradle Wrapper (Fix Lỗi 1)
        run: chmod +x gradlew

      - name: Chạy Unit Test với Gradle
        run: ./gradlew test

      - name: Đóng gói tệp JAR với Gradle
        run: ./gradlew bootJar --no-daemon

      - name: Lưu trữ thành phẩm JAR Artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-jar
          path: build/libs/*.jar
          retention-days: 1

  # ==============================================================================
  # Job 2: Đóng gói và phát hành Docker Image (Khắc phục Lỗi 2 & Lỗi 3)
  # ==============================================================================
  build-and-push:
    name: Build & Push Docker Image
    needs: test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v4

      - name: Tải về thành phẩm JAR từ Job test
        uses: actions/download-artifact@v4
        with:
          name: app-jar
          path: build/libs

      # Chuẩn hóa tên image thành chữ thường (quy định bắt buộc của GHCR & Docker)
      - name: Chuẩn hóa tên Docker Image thành chữ thường
        run: |
          echo "IMAGE_NAME=ghcr.io/${GITHUB_REPOSITORY,,}" >> $GITHUB_ENV

      - name: Thiết lập Docker Buildx
        uses: docker/setup-buildx-action@v3

      # FIX LỖI 2: Sửa đúng tên biến Secret đăng nhập Docker Registry
      - name: Đăng nhập vào GitHub Container Registry (Fix Lỗi 2)
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}

      # FIX LỖI 3: Cấu hình đúng Docker Build Context và đường dẫn Dockerfile
      - name: Đóng gói và đẩy Docker Image lên GHCR (Fix Lỗi 3)
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:latest
            ${{ env.IMAGE_NAME }}:${{ github.sha }}
```

---

## 5. Quy trình xác thực và kiểm tra kết quả tích xanh

### 5.1. Các bước triển khai lên GitHub
1. Khởi tạo kho mã nguồn Git và liên kết tới repository GitHub:
   ```bash
   git init -b main
   git remote add origin https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5.git
   ```
2. Đánh dấu cờ thực thi cho `gradlew`:
   ```bash
   git update-index --chmod=+x gradlew
   ```
3. Commit toàn bộ mã nguồn, cấu hình workflow và tài liệu:
   ```bash
   git add .
   git commit -m "feat: diagnose and fix 3 broken pipeline issues (Session 12 - Ex5)"
   git push -u origin main
   ```
4. Truy cập giao diện GitHub Actions để quan sát tiến trình:
   - Tất cả 2 Job `Build & Test Gradle` và `Build & Push Docker Image` đều chuyển sang trạng thái màu xanh lá cây (**Success / Passing**).

### 5.2. Đường dẫn kiểm tra trực tiếp
- **GitHub Actions Runs:** [https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5/actions](https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5/actions)
- **GitHub Packages (GHCR):** [https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5/pkgs/container/nguyenmanhhung_devops_ss12_5](https://github.com/HigaWateru/NguyenManhHung_DevOps_ss12_5/pkgs/container/nguyenmanhhung_devops_ss12_5)

---

## 6. Hình ảnh minh chứng kết quả tích xanh

Sau khi đẩy mã nguồn lên GitHub, truy cập vào tab **Actions**, chọn đợt chạy mới nhất và chụp ảnh kết quả:

![Kết quả tích xanh toàn bộ Pipeline CI/CD](../../../image/pipeline-success.png)

*Vị trí lưu trữ tệp ảnh:* `image/pipeline-success.png`
