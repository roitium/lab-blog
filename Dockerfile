# Base stage for building the static files
FROM node:lts AS base
WORKDIR /app

# Install the pnpm version pinned in package.json#packageManager
COPY package.json pnpm-lock.yaml ./
RUN npm install -g "$(node -p "require('./package.json').packageManager")" && pnpm --version
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm run build

# Runtime stage for serving the application
FROM nginx:mainline-alpine-slim AS runtime
COPY --from=base /app/dist /usr/share/nginx/html
EXPOSE 80
