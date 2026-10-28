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
