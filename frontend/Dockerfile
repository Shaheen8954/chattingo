# ------------------------------------------------------------
# ==================== Dependencies stage ==========================
# ------------------------------------------------------------
    FROM node:18-alpine AS deps
    WORKDIR /app
    COPY package.json package-lock.json* ./
    RUN npm install --no-audit --no-fund
    
    # ------------------------------------------------------------
    # ==================== Build stage =========================
    # ------------------------------------------------------------
    
    FROM node:18-alpine AS build
    WORKDIR /app
    COPY --from=deps /app/node_modules /app/node_modules
    COPY . .
    # Pass API URL at build time if provided
    ARG REACT_APP_API_URL
    ENV REACT_APP_API_URL=${REACT_APP_API_URL}
    RUN npm run build
    
    # ------------------------------------------------------------
    # ==================== Runtime stage ==========================
    # ------------------------------------------------------------
    FROM nginx:alpine AS runtime
    COPY --from=build /app/build /usr/share/nginx/html
    # Simple nginx config for SPA(Single Page Application)
    COPY public/nginx.conf /etc/nginx/conf.d/default.conf
    EXPOSE 80
    CMD ["nginx","-g","daemon off;"]