# Switch to local minikube env
eval $(minikube docker-env)

# Build all docker images
cd PhaseNet; docker build --tag phasenet-api:1.0 . ; cd ..;
cd GMMA; docker build --tag gmma-api:1.0 . ; cd ..;
cd spark; docker build --tag quakeflow-spark:1.0 .; cd ..;
cd waveform; docker build --tag quakeflow-waveform:1.0 .; cd ..;

# Deploy Kafka with Helm, create client and add topics
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install quakeflow-kafka bitnami/kafka  
kubectl run --quiet=true -it --rm quakeflow-kafka-client --restart='Never' --image docker.io/bitnami/kafka:2.7.0-debian-10-r68 --restart=Never \
    --command -- bash -c "kafka-topics.sh --create --topic phasenet_picks --bootstrap-server quakeflow-kafka.default.svc.cluster.local:9092 && kafka-topics.sh --create --topic gmma_events --bootstrap-server quakeflow-kafka.default.svc.cluster.local:9092 && kafka-topics.sh --create --topic waveform_raw --bootstrap-server quakeflow-kafka.default.svc.cluster.local:9092"

# Deploy to Kubernetes
kubectl apply -f metrics-server.yaml
kubectl delete -f metrics-server.yaml
kubectl apply -f quakeflow-local.yaml

# Add autoscaling
kubectl autoscale deployment phasenet-api --cpu-percent=80 --min=1 --max=10
kubectl autoscale deployment gmma-api --cpu-percent=80 --min=1 --max=10

# Expose APIs
kubectl expose deployment phasenet-api --type=LoadBalancer --name=phasenet-service
kubectl expose deployment gmma-api --type=LoadBalancer --name=gmma-service
