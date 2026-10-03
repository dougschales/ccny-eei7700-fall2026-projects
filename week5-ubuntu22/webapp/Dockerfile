FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Flask web app + tools that are useful once you have code execution on
# this box (mysql client to pivot into internal-db, netcat to catch/serve
# a shell) - the same "living off the land" idea as Week 4.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    netcat-openbsd \
    procps \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask requests

# internal-db doesn't offer TLS, but current default-mysql-client builds
# require it by default (mysql: "SSL is required, but the server does not
# support it"). Disable it client-side so a plain `mysql -h internal-db ...`
# just works once someone pivots here, instead of derailing on a confusing
# TLS error unrelated to the lab.
RUN mkdir -p /etc/mysql/conf.d && \
    printf '[client]\nssl=0\n' > /etc/mysql/conf.d/no-ssl.cnf

RUN mkdir -p /opt/app/docs /opt/app/notes /opt/app/config

COPY app.py /opt/app/app.py
COPY entrypoint.sh /opt/app/entrypoint.sh
COPY docs/ /opt/app/docs/
COPY notes/ /opt/app/notes/
COPY config/ /opt/app/config/

RUN chmod +x /opt/app/entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/opt/app/entrypoint.sh"]
