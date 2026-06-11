# ============================================================
# [01] IMAGE DE BASE
# Moodle 5.2 + PHP 8.3 + Apache
# ============================================================

FROM php:8.3-apache


# ============================================================
# [02] VARIABLES DE BUILD
# ============================================================

ARG MOODLE_VERSION=502
ENV MOODLE_TARBALL=moodle-latest-${MOODLE_VERSION}.tgz


# ============================================================
# [03] DÉPENDANCES SYSTÈME
# ============================================================

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    cron \
    wget \
    ca-certificates \
    postgresql-client \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libpq-dev \
    libxml2-dev \
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# [04] EXTENSIONS PHP REQUISES PAR MOODLE
# ============================================================

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        intl \
        zip \
        soap \
        exif \
        pgsql \
        pdo_pgsql \
        opcache


# ============================================================
# [05] EXTENSION REDIS
# ============================================================

RUN pecl install redis \
    && docker-php-ext-enable redis


# ============================================================
# [05b] INSTALLATION DE COMPOSER
# ============================================================

RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer


# ============================================================
# [06] MODULES APACHE
# ============================================================

RUN a2enmod rewrite headers ssl

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf


# ============================================================
# [07] INSTALLATION DE MOODLE
# Priorité :
#   1. Archive locale
#   2. Téléchargement officiel
# ============================================================

# IMPORTANT :
# Le build est lancé depuis :
#   docker build -f docker-images/moodle/Dockerfile .
#
# Donc le contexte Docker = racine projet
# => le chemin COPY doit être relatif à la racine

COPY ressource-local/moodle-latest-502.tgz /tmp/moodle.tgz

RUN set -eux; \
    \
    if [ -f /tmp/moodle.tgz ]; then \
        echo "📦 Utilisation archive Moodle locale"; \
    else \
        echo "🌐 Téléchargement Moodle officiel"; \
        curl -L \
        https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz \
        -o /tmp/moodle.tgz; \
    fi; \
    \
    mkdir -p /var/www; \
    \
    tar -xzf /tmp/moodle.tgz -C /var/www/; \
    \
    rm -f /tmp/moodle.tgz; \
    \
    echo "🔧 Installation des dépendances Composer..."; \
    cd /var/www/moodle && composer install --no-dev --optimize-autoloader --no-interaction 2>/dev/null || echo "⚠️ Composer install a échoué"; \
    \
    chown -R www-data:www-data /var/www/moodle


# ============================================================
# [08] RÉPERTOIRE MOODLEDATA
# ============================================================

RUN mkdir -p /var/www/moodledata \
    && chown -R www-data:www-data /var/www/moodle \
    && chown -R www-data:www-data /var/www/moodledata \
    && chmod -R 775 /var/www/moodledata


# ============================================================
# [09] CONFIGURATION APACHE
# ============================================================

COPY docker-images/moodle/moodle.conf \
    /etc/apache2/sites-available/000-default.conf


# ============================================================
# [10] ENTRYPOINT
# ============================================================

COPY docker-images/moodle/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh


# ============================================================
# [11] CONFIGURATION PHP
# ============================================================

RUN { \
    echo 'memory_limit=512M'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'max_execution_time=600'; \
    echo 'max_input_vars=5000'; \
    echo 'max_input_time=600'; \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=192'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'date.timezone=Europe/Paris'; \
} > /usr/local/etc/php/conf.d/moodle.ini


# ============================================================
# [12] WORKDIR
# ============================================================

WORKDIR /var/www/moodle


# ============================================================
# [13] PORT EXPOSE
# ============================================================

EXPOSE 80


# ============================================================
# [14] HEALTHCHECK
# ============================================================

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=120s \
    --retries=5 \
CMD curl -fsS http://localhost/ || exit 1


# ============================================================
# [15] ENTRYPOINT FINAL
# ============================================================

ENTRYPOINT ["/entrypoint.sh"]