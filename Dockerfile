# ==============================================================================
# Multi-stage Dockerfile cho ứng dụng Spring Boot Gradle
# Stage 1: Build ứng dụng tạo file jar
# ==============================================================================
FROM gradle:8.5-jdk17-alpine AS builder

WORKDIR /app

# Copy toàn bộ mã nguồn vào image builder
COPY . .

# Biên dịch và đóng gói ứng dụng (không cần daemon)
RUN gradle bootJar --no-daemon

# ==============================================================================
# Stage 2: Runtime image siêu nhẹ bằng Eclipse Temurin JRE 17 Alpine
# ==============================================================================
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Sao chép tệp JAR từ builder stage
COPY --from=builder /app/build/libs/*.jar app.jar

# Khai báo cổng ứng dụng lắng nghe
EXPOSE 8080

# Cấu hình bộ nhớ tối ưu cho JVM trong container
ENV JAVA_OPTS="-Xms256m -Xmx512m"

# Lệnh thực thi khởi chạy ứng dụng
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
