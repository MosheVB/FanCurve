FROM python:3.12-slim-bookworm

WORKDIR /app

ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY nvidia_fan_control.py .

# NVML and fan control use libraries injected by the NVIDIA Container Toolkit at runtime.
CMD ["python", "-u", "nvidia_fan_control.py"]
