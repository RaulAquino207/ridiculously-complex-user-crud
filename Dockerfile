### Multi-stage Dockerfile for NestJS app
FROM node:20-bullseye as builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --production=false
COPY . ./
RUN npm run build

FROM node:20-bullseye-slim
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main"]
