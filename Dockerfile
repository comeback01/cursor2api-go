# --- 阶段 1: 构建器 ---
# 使用 Go 镜像进行编译
FROM golang:1.24-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制并下载依赖项（利用 Docker 缓存）
COPY go.mod go.sum ./
RUN go mod download

# 复制所有源代码
COPY . .

# 编译应用为静态二进制文件
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o cursor2api-go .


# --- 阶段 2: 最终生产镜像 ---
# 从一个非常轻量的 Alpine 镜像开始
FROM alpine:latest

# 安装 ca-certificates, wget (用于 HEALTHCHECK), 和 nodejs (用于执行JS)
RUN apk --no-cache add ca-certificates wget nodejs

# 创建一个非 root 用户以提高安全性
RUN adduser -D -g '' appuser

# 设置工作目录为 /app
WORKDIR /app

# 从构建器阶段复制已编译的二进制文件
COPY --from=builder /app/cursor2api-go .

# 复制程序运行时必需的 jscode 和 static 文件夹
COPY --from=builder /app/jscode/ ./jscode/
COPY --from=builder /app/static/ ./static/

# 将工作目录的所有权赋予我们创建的非 root 用户
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser

# 暴露应用程序端口
EXPOSE 8002

# 添加健康检查，以便 Docker 知道应用是否正常运行
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8002/health || exit 1

# 启动应用程序的命令
CMD ["./cursor2api-go"]

