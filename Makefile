IMAGE_NAME = fluvio:sdf
WORKER_NAME = docker-worker
SDF_WORKER = sdf-worker

.PHONY: conn
run:
	fluvio topic create blue-sky-raw --retention-time '10s'	
	fluvio topic create blue-sky-raw-comment --retention-time '10s'	
	make conn

conn:
	./manage_conn.sh start conn/all.yaml
	./manage_conn.sh start conn/text.yaml

sdf:
	sdf run --ui
