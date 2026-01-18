FROM alpine:edge

# Install dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    git \
    mariadb \
    mariadb-client \
    php84 \
    php84-ctype \
    php84-curl \
    php84-dom \
    php84-fileinfo \
    php84-gd \
    php84-iconv \
    php84-intl \
    php84-json \
    php84-mbstring \
    php84-mysqli \
    php84-opcache \
    php84-openssl \
    php84-pdo_mysql \
    php84-phar \
    php84-session \
    php84-tokenizer \
    php84-xml \
    php84-xmlreader \
    php84-zip \
    php84-zlib \
    unit \
    unit-php84 \
""

# Ensure the 'unit' user and group exist
RUN getent group unit || addgroup -S unit && \
    getent passwd unit || adduser -S -G unit unit

# Clone WordPress to /var/www/wordpress/
WORKDIR /var/www
RUN git clone --depth 1 https://github.com/WordPress/WordPress.git wordpress

# Setup directories and permissions
RUN mkdir -p /var/lib/unit /run/unit /run/mysqld /var/lib/mysql \
    && chown unit:unit /var/lib/unit /run/unit \
    && chown mysql:mysql /run/mysqld /var/lib/mysql

RUN touch /var/log/php.log \
    && chown unit:unit /var/log/php.log

COPY config.json /config.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

CMD ["/entrypoint.sh"]
