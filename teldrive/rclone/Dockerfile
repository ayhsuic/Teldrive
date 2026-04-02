# 使用官方的 tgdrive/rclone 镜像作为基础
FROM ghcr.io/tgdrive/rclone:latest

# 将我们的启动脚本复制到容器中
COPY start.sh /start.sh

# 赋予脚本执行权限
RUN chmod +x /start.sh

# 设置容器的入口点 (启动时执行的命令)
ENTRYPOINT ["/start.sh"]
