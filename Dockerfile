FROM openresty/openresty:alpine
LABEL maintainer "nekocode <nekocode.cn@gmail.com>"

# 安装必要的工具
RUN apk add --no-cache bash logrotate iproute2 curl tar

# 安装 forego，用于启动多个服务
ARG FOREGO_VERSION="ekMN3bCZFUn"
RUN curl "https://bin.equinox.io/c/${FOREGO_VERSION}/forego-stable-linux-amd64.tgz" -Lo /tmp/forego.tgz
RUN cd /usr/local/bin && tar -xzf /tmp/forego.tgz \
    && chmod +x /usr/local/bin/forego \
    && rm /tmp/forego.tgz

# 创建目录
RUN mkdir -p /conf /nginx/logs

# 环境变量
ENV RATE_LIMIT true

# 复制文件
COPY ./nginx /nginx
COPY * /

VOLUME /conf
EXPOSE 80

ENTRYPOINT ["/main.sh"]
