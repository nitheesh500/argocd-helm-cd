#!/bin/bash

run_cmd(){

    echo "$*"
    OUTPUT=$("$@" 2>&1)
    STATUS=$?

    echo "$OUTPUT"

    if [ $STATUS -ne 0 ]; then
        echo "command failed: $*"
        exit $STATUS
    fi

}

echo "🚀 Step 1: Adding Argo CD Helm repo"
run_cmd helm repo add argo https://argoproj.github.io/argo-helm

run_cmd helm repo update

echo "📦 Step 2: Create namespace"
run_cmd kubectl create namespace argocd || echo "Namespace already exists"

echo "🧩 Step 3: Install Argo CD using Helm"
run_cmd helm install argocd argo/argo-cd --namespace argocd

echo "🔍 Step 4: Verify installation"
run_cmd kubectl get pods -n argocd

echo "🌐 Step 5: Expose Argo CD UI - LoadBalancer"
run_cmd kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "Get external IP:"
run_cmd kubectl get svc argocd-server -n argocd

#echo "🔐 Step 6: Get Argo CD admin password"
#run_cmd kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode

