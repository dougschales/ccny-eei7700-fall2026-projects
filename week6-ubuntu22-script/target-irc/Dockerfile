FROM docker.io/library/python:3.11-slim

COPY app.py /opt/app.py
COPY flag3.txt /opt/flag3.txt
RUN chmod 644 /opt/flag3.txt

EXPOSE 6667

CMD ["python3", "-u", "/opt/app.py"]
