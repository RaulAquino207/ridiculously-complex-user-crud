###############################
# Base image
###############################
FROM node:20-bullseye-slim AS base
WORKDIR /usr/src/app
ENV NODE_ENV=production \
	PORT=3000 \
	NODE_OPTIONS=--enable-source-maps

# Ensure workdir is owned by non-root user
USER root
RUN chown -R node:node /usr/src/app
USER node

###############################
# Install production deps only (cached separately)
###############################
FROM base AS deps
USER root
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev && \
	chown -R node:node /usr/src/app
USER node

###############################
# Install full deps for building
###############################
FROM base AS dev-deps
ENV NODE_ENV=development
USER root
COPY package.json package-lock.json* ./
RUN npm ci --include=dev && \
	chown -R node:node /usr/src/app
USER node

###############################
# Development stage (hot reload)
###############################
FROM node:20-bullseye AS development
WORKDIR /usr/src/app
ENV NODE_ENV=development \
	PORT=3000
COPY package.json package-lock.json* ./
RUN npm ci
COPY . ./
EXPOSE 3000
CMD ["npm", "run", "start:dev"]

###############################
# Build stage (uses dev dependencies)
###############################
FROM base AS builder
ENV NODE_ENV=development
COPY --chown=node:node . ./
COPY --from=dev-deps --chown=node:node /usr/src/app/node_modules ./node_modules
RUN npm run build

###############################
# Testing run stage (same as prod runtime but NODE_ENV=testing)
###############################
FROM base AS testing
ENV NODE_ENV=testing
COPY --from=deps --chown=node:node /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=node:node /usr/src/app/dist ./dist
COPY --chown=node:node package.json ./
EXPOSE 3002
HEALTHCHECK --interval=10s --timeout=3s --retries=5 CMD node -e "require('net').connect(process.env.PORT||3000,'127.0.0.1').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))"
CMD ["node", "dist/main"]

###############################
# Production run stage
###############################
FROM base AS production
ENV NODE_ENV=production
COPY --from=deps --chown=node:node /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=node:node /usr/src/app/dist ./dist
COPY --chown=node:node package.json ./
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD node -e "require('net').connect(process.env.PORT||3000,'127.0.0.1').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))"
CMD ["node", "dist/main"]
