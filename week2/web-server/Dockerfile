FROM nginx:alpine

# Install Python3 to run the hidden service on the high port
RUN apk add --no-cache python3

# Copy the Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the static web pages
COPY default.html /usr/share/nginx/html/index.html
COPY dev.html /usr/share/nginx/html/dev.html

# Copy the startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80 31337

CMD ["/start.sh"]
