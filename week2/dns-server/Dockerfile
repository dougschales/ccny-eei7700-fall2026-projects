FROM alpine:latest

RUN apk add --no-cache bind

COPY named.conf.options /etc/bind/named.conf.options
COPY named.conf.local /etc/bind/named.conf.local
COPY db.target.local /etc/bind/db.target.local

# Include the options and local configurations into the main config
RUN echo 'include "/etc/bind/named.conf.options";' > /etc/bind/named.conf && \
    echo 'include "/etc/bind/named.conf.local";' >> /etc/bind/named.conf

EXPOSE 53/tcp 53/udp

CMD ["named", "-c", "/etc/bind/named.conf", "-g"]
