### 🧩 FULL TRAFFIC FLOW (END-USER TO POD)
```
User (Browser)
  ↓
DNS (petclinic.example.com)
  ↓
LoadBalancer (Ingress Controller)
  ↓
Ingress (rules)
  ↓
Service (petclinic-svc)
  ↓
Pod(s) (petclinic-app)
```
helm install petclinic ./helm/petclinic -n petclinic