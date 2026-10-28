# [Bài Tập Thực Hành]: Hệ sinh thái giám sát Prometheus từ A-Z

## 1. Mô tả bài toán
Hệ thống backend đôi khi gặp hiện tượng chậm chạp. Để theo dõi sát sao "nhịp tim" và tình trạng hoạt động của toàn bộ hạ tầng, chúng ta triển khai Prometheus để giám sát song song:
- **Phần cứng / Máy chủ OS (VPS)**: Giám sát CPU, RAM, Disk, Network I/O thông qua `node-exporter`.
- **Phần mềm (Spring Boot Application)**: Giám sát JVM memory, Heap, Threads, GC, HTTP request latency thông qua `Spring Boot Actuator` và `Micrometer Prometheus registry`.

---

## 2. Kiến trúc giải pháp (Architecture)

```
                     +---------------------------------------+
                     |         Prometheus (Port 9090)        |
                     +-------------------+-------------------+
                                         |
                       Pull Metrics      |      Pull Metrics
                     (every 5 seconds)   |   (every 5 seconds)
                                         |
             +---------------------------+---------------------------+
             |                                                       |
             v                                                       v
+---------------------------+                         +---------------------------+
|  Node Exporter (9100)     |                         |  Spring Boot Backend      |
|  - CPU / RAM / Disk / Net |                         |  - Port 8080              |
|  - Metrics: /metrics      |                         |  - Actuator: /actuator/   |
+---------------------------+                         |    prometheus             |
                                                      +---------------------------+
```

---

## 3. Cấu trúc thư mục dự án

```
exercise_07/
├── src/
│   ├── main/
│   │   ├── java/com/example/monitoring/
│   │   │   ├── BackendApplication.java
│   │   │   └── controller/
│   │   │       └── ApiController.java
│   │   └── resources/
│   │       └── application.yml
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── gradlew                  # Gradle wrapper script (Linux/macOS)
├── gradlew.bat              # Gradle wrapper script (Windows)
├── build.gradle             # Cấu hình Gradle build & dependencies
├── settings.gradle
├── pom.xml                  # Cấu hình Maven (dự phòng)
├── .dockerignore
├── Dockerfile               # Multi-stage build trực tiếp bằng gradlew
├── docker-compose.yml       # Điều phối backend, node-exporter, prometheus
├── prometheus.yml           # Cấu hình scrape targets cho Prometheus
└── README.md
```

---

## 4. Chi tiết cấu hình từng thành phần

### Bước 1: Ứng dụng Spring Boot
- **Dependencies chính**:
  - `org.springframework.boot:spring-boot-starter-web`
  - `org.springframework.boot:spring-boot-starter-actuator`
  - `io.micrometer:micrometer-registry-prometheus`
- **File cấu hình `src/main/resources/application.yml`**:
  ```yaml
  server:
    port: 8080

  spring:
    application:
      name: backend-service

  management:
    endpoints:
      web:
        exposure:
          include: prometheus, health, info
    endpoint:
      health:
        show-details: always
      prometheus:
        enabled: true
    metrics:
      tags:
        application: ${spring.application.name}
  ```

### Bước 2: Cấu hình Prometheus (`prometheus.yml`)
```yaml
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'spring_boot'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['backend:8080']
```

### Bước 3: Docker Compose (`docker-compose.yml`)
```yaml
version: '3.8'

services:
  backend:
    build: . # Build spring boot app
    container_name: backend
    ports:
      - "8080:8080"
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    restart: unless-stopped
    depends_on:
      - backend
      - node-exporter
```

### Bước 4: Dockerfile Multi-Stage Build với Gradle Wrapper (`gradlew`)
Dockerfile tự động dùng `gradlew` đóng gói file `.jar` ngay trong container mà không cần máy host phải cài đặt hay build thủ công trước:
```dockerfile
# Stage 1: Build ứng dụng Spring Boot bằng Gradle Wrapper (gradlew)
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app

# Copy Gradle wrapper và các file cấu hình
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./

# Cấp quyền thực thi cho gradlew
RUN chmod +x gradlew

# Copy source code và tiến hành đóng gói file JAR
COPY src src
RUN ./gradlew bootJar --no-daemon

# Stage 2: Runtime image gọn nhẹ sử dụng Temurin JRE
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/backend.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 5. Hướng dẫn khởi chạy và kiểm tra

### Khởi chạy:
Chỉ cần chạy 1 lệnh duy nhất:
```bash
docker compose up -d --build
```
*(Docker sẽ tự dùng `./gradlew bootJar` trong container để build mã nguồn và khởi động cả 3 service)*

### Kiểm tra kết quả:
1. **Kiểm tra trạng thái container**:
   ```bash
   docker compose ps
   ```
2. **Kiểm tra Spring Boot Actuator**:
   - Health check: `http://localhost:8080/actuator/health` -> Trả về `{"status":"UP"}`.
   - Endpoint test: `http://localhost:8080/api/hello` -> Trả về JSON heartbeat.
   - Prometheus metrics endpoint: `http://localhost:8080/actuator/prometheus` -> Chứa danh sách JVM metrics, GC, threads, HTTP requests.
3. **Kiểm tra Node Exporter**:
   - Metrics endpoint: `http://localhost:9100/metrics` -> Chứa dữ liệu CPU, RAM, disk của host.
4. **Kiểm tra Prometheus UI & Targets**:
   - Truy cập: `http://localhost:9090/targets`
   - Xác nhận cả 2 targets đều ở trạng thái **UP (1/1 up)**:
     - `node_exporter` (`http://node-exporter:9100/metrics`) -> **UP**
     - `spring_boot` (`http://backend:8080/actuator/prometheus`) -> **UP**
   - Vào thẻ `Graph` hoặc gõ query `up` để thấy cả 2 mục tiêu đều trả về giá trị `1`.
