# Stage 1: Build Flutter Web directly inside Docker
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG ORCHESTRATOR_URL=https://orchestrator-service-eb3iwos6ma-ew.a.run.app

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --wasm --dart-define=ORCHESTRATOR_URL=${ORCHESTRATOR_URL}

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]