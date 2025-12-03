# Stage 1: Base setup and dependencies
FROM node:20-alpine AS base
WORKDIR /app

# Enable corepack and pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install build dependencies for native modules
RUN apk add --no-cache libc6-compat

# Stage 2: Dependencies installation
FROM base AS deps
ENV NODE_ENV=production

# Install sharp and other build dependencies
RUN pnpm add sharp@latest

# Copy only package files for better layer caching
COPY package.json pnpm-lock.yaml* ./

# Install production dependencies only
RUN pnpm install --frozen-lockfile --prod=false

# Stage 3: Build the application
FROM base AS builder
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max-old-space-size=2048"

# Copy node_modules from deps
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Build the application
RUN pnpm build

# Prune dev dependencies
RUN pnpm prune --prod

# Stage 4: Production runner
FROM base AS runner
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max-old-space-size=512"

# Create a non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy necessary files from builder
COPY --from=builder --chown=nextjs:nodejs /app/next.config.mjs ./
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Set the user
USER nextjs

# Expose port and start the application
EXPOSE 3000
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

# Use the standalone server with proper host and port configuration
CMD ["pnpm", "start", "--", "-p", "3000", "-H", "0.0.0.0"]
