FROM nginx:alpine

# Copy custom Nginx configuration
COPY default.conf /etc/nginx/conf.d/default.conf

# Copy the static website files to the nginx html directory
COPY src/ /usr/share/nginx/html/

# Expose port 80
EXPOSE 80
