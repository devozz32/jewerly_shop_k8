# ---------- Build Stage ----------
    FROM node:18 AS build
    WORKDIR /app
    
    # Environment variables for the React build
    ENV REACT_APP_API_BASE_URL=http://jewelry.local/api \
        REACT_APP_AUTH_BASE_URL=http://jewelry.local/auth \
        REACT_APP_BACKEND_HOST=api \
        REACT_APP_BACKEND_PORT=8000
    
    COPY package*.json ./
    RUN npm install
    COPY . .
    
    # Build React app with environment variables baked in
    RUN npm run build
    
    
    # ---------- Production Stage ----------
    FROM nginx:alpine AS production
    
    # Copy compiled build files from the build stage
    COPY --from=build /app/build /usr/share/nginx/html
    
    EXPOSE 80
    
    CMD ["nginx", "-g", "daemon off;"]
    