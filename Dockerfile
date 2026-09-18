# Stage 1: Build Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency configs
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code and assets
COPY . .
RUN flutter config --no-analytics
RUN flutter build web --release

# Stage 2: Serve using high-performance lightweight Nginx
FROM nginx:alpine

# Copy built web assets to Nginx html directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80 for Render / Web hosting
EXPOSE 80

# Run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
