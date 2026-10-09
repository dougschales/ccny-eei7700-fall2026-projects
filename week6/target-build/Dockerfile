FROM docker.io/library/python:3.11-slim

COPY app.py /opt/app.py
COPY flag2.txt /opt/flag2.txt
RUN chmod 644 /opt/flag2.txt

EXPOSE 3632

CMD ["python3", "-u", "/opt/app.py"]
