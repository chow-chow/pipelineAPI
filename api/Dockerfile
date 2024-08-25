FROM python:3.12-slim
WORKDIR /src
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
COPY requirements.txt /src/requirements.txt
RUN pip install --no-cache-dir -r /src/requirements.txt
COPY . /src
EXPOSE 8080
CMD ["python", "run.py"]


