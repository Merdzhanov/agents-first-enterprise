# Using a lightweight and fast Nginx server
FROM nginx:alpine

# Copy our Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the already built Flutter Web files from the new folder
COPY build/web /usr/share/nginx/html

# Expose port 8080 (requirement of Cloud Run)
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]