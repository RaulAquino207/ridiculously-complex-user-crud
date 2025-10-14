# Development stage (hot reload)
FROM node:20-bullseye as development
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm ci
COPY . ./
EXPOSE 3000
CMD ["npm", "run", "start:dev"]

# Production build stage
FROM node:20-bullseye as builder
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm ci --production=false
COPY . ./
RUN npm run build

# Testing run stage
FROM node:20-bullseye-slim as testing
WORKDIR /usr/src/app
ENV NODE_ENV=testing
COPY --from=builder /usr/src/app/package.json ./
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/dist ./dist
EXPOSE 3002
CMD ["node", "dist/main"]

# Production run stage
FROM node:20-bullseye-slim as production
WORKDIR /usr/src/app
ENV NODE_ENV=production
COPY --from=builder /usr/src/app/package.json ./
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main"]
