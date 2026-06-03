# Moodle Custom Image for K3s
FROM php:8.3-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    libpq-dev \
    git \
    unzip \
    cron \
    postgresql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install mysqli pgsql pdo pdo_mysql pdo_pgsql \
    && docker-php-ext-install zip intl soap opcache exif \
    && rm -rf /var/lib/apt/lists/*

# Install Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Download and install Moodle (dernière version stable 5.2)
ENV MOODLE_VERSION=5.2

RUN mkdir -p /var/www/moodle \
    && git clone --depth 1 --branch MOODLE_502_STABLE https://github.com/moodle/moodle.git /var/www/moodle \
    && cd /var/www/moodle \
    && composer install --no-dev --classmap-authoritative --prefer-dist --no-interaction \
    && chown -R www-data:www-data /var/www/moodle \
    && mkdir -p /var/www/moodledata \
    && chown -R www-data:www-data /var/www/moodledata \
    && mkdir -p /var/www/moodle/public \
    && chown -R www-data:www-data /var/www/moodle/public

# Apache configuration
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && a2enmod rewrite ssl headers

COPY moodle.conf /etc/apache2/sites-available/000-default.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# PHP configuration
RUN { \
    echo 'memory_limit = 512M'; \
    echo 'upload_max_filesize = 128M'; \
    echo 'post_max_size = 128M'; \
    echo 'max_execution_time = 600'; \
    echo 'max_input_vars = 5000'; \
} > /usr/local/etc/php/conf.d/moodle.ini

# Set working directory
WORKDIR /var/www/moodle

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:80 || exit 1

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
