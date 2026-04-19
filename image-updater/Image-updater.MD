# 🚀 Argo CD Image Updater in Real Projects (GitOps Explained)

## 📌 1. Scenario

You are working in a **microservices-based architecture**:

- Multiple services (user, order, payment)
- Each service is containerized using Docker
- Images are pushed to a container registry (e.g., AWS ECR)
- Kubernetes deployments are managed using Helm charts
- Argo CD is used for GitOps-based deployment

---

## ⚠️ 2. The Problem

In a **standard GitOps workflow**:

1. CI builds a Docker image → pushes to registry
2. Kubernetes deployment depends on `values.yaml` (image tag)
3. ❗ But Git is NOT updated automatically

### Issues:

- Manual update required in `values.yaml`
- Slower deployments
- Human errors (wrong tag, missed updates)
- CI/CD pipeline becomes partially manual

### YOUR CURRENT APPROACH (CI updates Git using sed)

What your pipeline is doing

```bashS
# Build & push image
docker build -t my-app:${BUILD_NUMBER} .
docker push myrepo/my-app:${BUILD_NUMBER}

# Clone CD repo
git clone https://github.com/org/cd-repo.git
cd cd-repo

# Update Helm values.yaml
sed -i "s/tag:.*/tag: ${BUILD_NUMBER}/" helm/values.yaml

# Commit & push
git config user.name "ci-bot"
git config user.email "ci@company.com"
git add helm/values.yaml
git commit -m "Update image tag to ${BUILD_NUMBER}"
git push origin main
```
⚠️ Downsides (this is what you say in interview)
- CI is doing too many responsibilities (build + deploy trigger)
- Requires Git credentials inside CI
- Hard to manage when scaling across many services
- Custom scripting (sed) → brittle
---

## ✅ 3. The Solution

Use **Argo CD Image Updater**

### What it does:

```
CI (Jenkins)
   ↓
Build + Push Image (ECR)
   ↓
Argo CD Image Updater (inside cluster)
   ↓
Updates values.yaml in Git
   ↓
Argo CD detects Git change
   ↓
Deploys to Kubernetes
```

### 🎯 Who actually updates values.yaml?

After CI completes:

- CI builds image → pushes to ECR
- Image Updater (running as a pod in cluster)
  - It checks registry → finds new tag
  - It updates values.yaml in Git repo
- Argo CD detects change → deploys


---
## 🔑 Update Strategies

## 🔑 Update Strategies

| Strategy | Description                         | Example                          |
|----------|-------------------------------------|----------------------------------|
| latest   | Always picks the latest image       | nginx:latest                     |
| semver   | Follows semantic versioning         | myapp:1.2.3 → 1.2.4              |
| name     | Matches tag patterns                | myapp:prod-*                     |
| digest   | Tracks image digest changes         | nginx@sha256:abc123...           |


## 🧠 Prerequisites

Before installing, ensure:

- Kubernetes cluster (EKS / AKS / GKE)
- Argo CD installed and running
- kubectl access configured
- Git repository for manifests (Helm or YAML)
- Container registry access (ECR / Docker Hub / GCR)

## 🏗️ Installation Methods

### ✅ Method 1: Install via Kubernetes Manifest (Recommended)

---

### 🔹 Step 1: Ensure Namespace Exists

```bash
kubectl create namespace argocd
```

### 🔹 Step 2: Install Image Updater

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/master/manifests/install.yaml
```

### 🔹 Step 3: Verify Installation
```bash
kubectl get pods -n argocd
```

Expected output:
```
argocd-image-updater-xxxxx   Running
```
---
## 🔐 Git Access Configuration

Image Updater needs permission to update your Git repo.

### 🔹 Option A: Username & Token
```bash
kubectl create secret generic git-creds \
  -n argocd \
  --from-literal=username=<your-username> \
  --from-literal=password=<your-token>
```
### 🔹 Option B: SSH Key

```bash
kubectl create secret generic git-creds \
  -n argocd \
  --from-file=sshPrivateKey=~/.ssh/id_rsa
```
### 🔹 Link Credentials in ConfigMap

```bash
kubectl edit configmap argocd-image-updater-config -n argocd
```
Add:

```yaml
git:
  usernameSecret:
    name: git-creds
    key: username
  passwordSecret:
    name: git-creds
    key: password
```
---

## 🐳 Registry Access Configuration

### 🔹 Example: AWS ECR
```bash
kubectl create secret docker-registry ecr-creds \
  -n argocd \
  --docker-server=<account>.dkr.ecr.<region>.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password)
```

💡 Recommended: Use IAM Role (IRSA) instead of static credentials


---
## 🔁 Real Flow (Your Project)
```
Your Microservice Code
        ↓
Docker Image (ECR)
        ↓
Helm values.yaml (image tag)
        ↓
Argo CD Application (points to Helm)
        ↓
Kubernetes Deployment (runs your app)
```

###🎯 Big Picture (Microservices + GitOps)
---
### You don’t have one app—you have many services:

- user-service
- order-service
- payment-service
- notification-service

### 🗂️ Typical Repo Structure (CD repo)
```
cd-repo/
  user-service/
    Chart.yaml
    values.yaml
  order-service/
    Chart.yaml
    values.yaml
  payment-service/
    Chart.yaml
    values.yaml
```

👉 Each folder = one microservice deployment config  

``1 Microservice = 1 Helm Chart = 1 Argo CD Application``

### ⚙️ Option 1: One Argo CD Application per Microservice (Most Common)

Example: user-service Application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service
  annotations:
    argocd-image-updater.argoproj.io/image-list: user=myrepo/user-service
    argocd-image-updater.argoproj.io/user.update-strategy: latest
    argocd-image-updater.argoproj.io/write-back-method: git
spec:
  source:
    repoURL: https://github.com/org/cd-repo.git
    path: user-service/
```
👉 Same pattern for each service

### 🔁 Flow for ONE Microservice

Let’s say user-service:
```
Developer → push code
        ↓
CI builds → myrepo/user-service:v2
        ↓
Image Updater detects new image
        ↓
Updates user-service/values.yaml
        ↓
Argo CD deploys only user-service

```

### 🔁 Correct Flow (Important)

Step-by-step:

1. Argo CD reads:
```yaml
repoURL: https://github.com/org/cd-repo.git
path: user-service/
```
2. It goes to Git → user-service/
3. Inside that folder, it finds:
   - Helm chart (Chart.yaml)
   - values.yaml  
4. Argo CD:
    - Runs Helm template internally
    - Generates Kubernetes manifests
5. Then:
   - Applies them to cluster (kubectl apply equivalent)

### Flow becomes:
```
 CI → push image
   ↓
Image Updater updates values.yaml in Git
   ↓
Argo CD detects Git change
   ↓
Re-syncs Helm chart
   ↓
Deploys updated version
```
---
 