# Use an official Python runtime as a parent image
# Using python:3.8-slim-bullseye as Bullseye is newer than Buster and might have updated packages
FROM python:3.8-slim-bullseye

# Set environment variables
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV DEBIAN_FRONTEND=noninteractive

# Update OS packages and install/upgrade zlib1g and libdb5.3, then clean up.
# This step is crucial for addressing OS-level vulnerabilities.
# Running it early helps with Docker layer caching.
RUN apt-get update && \
    apt-get install -y --no-install-recommends zlib1g libdb5.3 && \
    apt-get upgrade -y zlib1g libdb5.3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
# Using --no-cache-dir to reduce image size
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
COPY . .

# Make port 5000 available to the world outside this container
EXPOSE 5000

# Define environment variable for the Gunicorn workers (optional, can be overridden)
ENV GUNICORN_WORKERS 4

# Run app.py when the container launches
# Use Gunicorn as the WSGI server
CMD ["gunicorn", "-b", "0.0.0.0:5000", "--workers=${GUNICORN_WORKERS}", "--log-level=info", "run:app"]
