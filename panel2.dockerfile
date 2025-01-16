FROM --platform=$TARGETOS/$TARGETARCH docker.io/library/almalinux:9-minimal AS base

LABEL maintainer="Cameron Carney <ccarney@zyphi.co>"

# Allows the end user to customize what PHP modules and packages they want at build time
ENV PHP_VERSION=8.2
ENV PHP_MODULES=bcmath,cli,common,fpm,gd,gmp,intl,json,mbstring,mysqlnd,opcache,pdo,pecl-zip,process,soap,sodium,xml,zstd
ENV EXTRA_PACKAGES="nmap-ncat mariadb"

# Create the www-data group and user with ID 33 (common default for www-data)
RUN microdnf install -y shadow-utils tzdata && \
    groupadd -r -g 500 www-data && \
    useradd -r -g www-data -u 33 -d /var/lib/caddy -s /sbin/nologin -c 'Web server user' www-data && \
    install -d -m 0750 -o www-data -g www-data /var/lib/caddy

RUN curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - && \
    microdnf install -y nodejs && \
    microdnf clean all
# Install any required dependencies for the container to operate
RUN rpm --install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    rpm --install https://rpms.remirepo.net/enterprise/remi-release-9.rpm && \
    curl -Lo /etc/yum.repos.d/caddy.repo https://copr.fedorainfracloud.org/coprs/g/caddy/caddy/repo/epel-9/group_caddy-caddy-epel-9.repo && \
    microdnf module enable -y php:remi-${PHP_VERSION} nodejs:20 && \
    eval microdnf install -y ca-certificates caddy php-{$PHP_MODULES} \
        python3 python3-pip tini ${EXTRA_PACKAGES} && \
    pip3 install yacron && \
    microdnf clean all && \
    pip3 cache purge && \
    npm i -g yarn;

# Copy contents to root directory
COPY ./root/ /

# Export a persistent volume for the application to store persistent data
VOLUME [ "/var/lib/caddy" ]

WORKDIR /var/www/html

# Let tini execute /entrypoint. This allows proper reaping of processes
# ...
ENTRYPOINT [ "/usr/bin/tini", "--", "/entrypoint.sh" ]
CMD [ "start-web" ]

# Build phase of the container
# This is where composer is added and Pterodactyl is properly setup
FROM base AS build

ARG VERSION
ARG GIT_BRANCH=release/v1.11.10

ENV VERSION=${VERSION}
ENV NODE_OPTIONS=--openssl-legacy-provider

# Install additional build dependencies
RUN \
    microdnf install -y findutils git ca-certificates gnupg nano wget git zip unzip 

RUN \
    git clone https://github.com/pterodactyl/panel ./ --depth 1 --branch ${GIT_BRANCH} && \
    rm .git -rf && \
    chmod -R 755 storage/* bootstrap/cache && \
    find storage -type d > .storage.tmpl && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    cp .env.example .env && \
    composer install --ansi --no-dev --optimize-autoloader && \
    chown -R www-data:www-data *;

RUN yarn config set registry https://registry.npmjs.org/
RUN curl -v https://registry.npmjs.org/
RUN \
    yarn install --production && \
    yarn add cross-env && \
    yarn run build:production && \
    rm -rf node_modules


# Remove persistent data folders as they will be symlinked further down
RUN rm .env ./storage -rf

# Final Production phase of the controller
# All build requirements get scrapped as to maintain a small image
FROM base AS production

ARG VERSION
ENV VERSION=${VERSION}

COPY --from=build --chown=www-data:www-data /var/www /var/www

# Symlink storage, config, and cache to /data
RUN \
    ln -s /data/storage storage && \
    ln -s /data/pterodactyl.conf .env;

RUN \
    wget "$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)" -O release.zip && \
    unzip release.zip && \
    echo -e "DOCKER='n'\nFOLDER='/var/www/html'" > .blueprintrc && \
    chmod +x blueprint.sh && \
    ./blueprint.sh;

VOLUME [ "/data" ]