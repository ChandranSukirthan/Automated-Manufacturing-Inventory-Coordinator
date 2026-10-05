FROM python:3.12-slim
WORKDIR /app
COPY ai/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY ai/ /app/ai/
RUN useradd -u 10001 -m amic && mkdir /data && chown -R amic:amic /app /data
ENV AMIC_WORKFLOW_DB=/data/workflow_state.sqlite3
USER amic
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "ai.main:app", "--host", "0.0.0.0", "--port", "8000"]
