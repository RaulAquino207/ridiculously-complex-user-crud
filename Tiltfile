docker_build('ridiculously-complex-user-crud', '.')

k8s_yaml('k8s/api-configmap.yaml')
k8s_yaml('k8s/localstack-deployment.yaml')
k8s_yaml('k8s/localstack-service.yaml')
k8s_yaml('k8s/api-deployment.yaml')
k8s_yaml('k8s/api-service.yaml')

k8s_resource('ridiculously-complex-api', port_forwards=3000)
k8s_resource('localstack', port_forwards=4566)

allow_k8s_contexts(['kind-kind', 'docker-desktop', 'minikube'])
