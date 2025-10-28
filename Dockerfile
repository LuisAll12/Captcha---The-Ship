# syntax=docker/dockerfile:1

ARG NODE_VERSION=20-alpine
ARG PNPM_VERSION=9

############################
# Builder
############################
FROM node:${NODE_VERSION} AS builder
WORKDIR /app

# Paketmanager optional festlegen
# Du kannst wahlweise npm oder pnpm verwenden
# Für pnpm auskommentieren und lockfile anpassen
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

COPY package.json pnpm-lock.yaml* package-lock.json* yarn.lock* ./
# Wählt automatisch den passenden Installer je nach vorhandenem Lockfile
RUN if [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f yarn.lock ]; then corepack yarn install --frozen-lockfile; \
    else npm install; fi

COPY . .
# Für Production Builds
RUN if [ -f pnpm-lock.yaml ]; then pnpm build; \
    elif [ -f package-lock.json ]; then npm run build; \
    elif [ -f yarn.lock ]; then corepack yarn build; \
    else npm run build; fi


############################
# Production Image mit Nginx
############################
FROM nginx:1.29.2-alpine AS prod
COPY --from=builder /app/dist /usr/share/nginx/html

# optional: eigene nginx.conf
# COPY ./infra/nginx.conf /etc/nginx/conf.d/default.conf

COPY ./infra/entrypoint-config.sh /docker-entrypoint.d/99-gen-config.sh
RUN chmod +x /docker-entrypoint.d/99-gen-config.sh

EXPOSE 80
CMD ["nginx","-g","daemon off;"]

