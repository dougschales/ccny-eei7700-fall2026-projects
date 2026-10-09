FROM docker.io/library/python:3.11-slim

COPY app.py /opt/app.py
COPY flag1.txt /opt/flag1.txt
RUN chmod 644 /opt/flag1.txt

EXPOSE 21 6200

CMD ["python3", "-u", "/opt/app.py"]
