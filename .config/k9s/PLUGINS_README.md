# K9s Plugins Complete Reference Guide

## Table of Contents
- [Quick Reference Table](#quick-reference-table)
- [Installation](#installation)
- [Plugin Categories](#plugin-categories)
  - [Debugging & Troubleshooting](#debugging--troubleshooting)
  - [Logs & Monitoring](#logs--monitoring)
  - [Editing & Configuration](#editing--configuration)
  - [Container Operations](#container-operations)
  - [Deployment Operations](#deployment-operations)
  - [Networking](#networking)
  - [Flux GitOps](#flux-gitops)
  - [Observability](#observability)
  - [Node Operations](#node-operations)
  - [Helm Operations](#helm-operations)
  - [ArgoCD Integration](#argocd-integration)
  - [Certificate Management](#certificate-management)
  - [Resource Optimization](#resource-optimization)
  - [Advanced Troubleshooting](#advanced-troubleshooting)
  - [Job Management](#job-management)
  - [Specialized Integrations](#specialized-integrations)
- [Common Troubleshooting Scenarios](#common-troubleshooting-scenarios)
- [Tips & Best Practices](#tips--best-practices)

## Quick Reference Table

| Keybinding | Description | Category | Danger Level |
|------------|-------------|----------|--------------|
| `b` | Bash shell into container | Container Ops | Safe |
| `Ctrl-L` | Multi-pod logs with Stern | Logs | Safe |
| `Shift-E` | Show events for resource | Observability | Safe |
| `Ctrl-O` | Edit YAML in Neovim | Editing | Safe |
| `Ctrl-Y` | Copy YAML to clipboard | Editing | Safe |
| `Shift-R` | Restart deployment | Deployment | Moderate |
| `Shift-K` | Port-forward (interactive) | Networking | Safe |
| `Shift-D` | Debug container / Drain node | Debug/Node | High |
| `w` | Watch resource changes | Observability | Safe |
| `d` | Dive image analysis | Container Ops | Safe |
| `v` | Show Helm values | Helm | Safe |
| `Ctrl-F` | Remove finalizers | Troubleshooting | **DANGEROUS** |
| `Shift-V` | Trivy security scan | Security | Safe |
| `j` | Parse JSON logs | Logs | Safe |
| `Shift-W` | Show pod metrics | Monitoring | Safe |
| `Shift-S` | Scale deployment | Deployment | Moderate |
| `Ctrl-G` | Network debug container | Networking | Safe |
| `Shift-P` | Debug PVC mount | Storage | Safe |
| `Ctrl-J` | Toggle CronJob | Jobs | Moderate |
| `F5` | Shell with sh | Container Ops | Safe |
| `F6` | Shell + install nvim | Container Ops | Safe |

## Installation

### Install All Dependencies Script

```bash
#!/bin/bash
# k9s-plugins-dependencies.sh

echo "Installing k9s plugin dependencies..."

# Core tools
echo "Installing core tools..."
brew install kubectl stern dive jq watch

# Security & Analysis
echo "Installing security tools..."
brew install aquasecurity/trivy/trivy

# Helm ecosystem
echo "Installing Helm and plugins..."
brew install helm
helm plugin install https://github.com/databus23/helm-diff

# GitOps tools
echo "Installing GitOps tools..."
brew install fluxcd/tap/flux
brew install argocd

# kubectl plugins via krew
echo "Installing kubectl plugins..."
# Install krew if not already installed
if ! kubectl krew version &> /dev/null; then
    echo "Installing krew..."
    (
      set -x; cd "$(mktemp -d)" &&
      OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
      ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
      KREW="krew-${OS}_${ARCH}" &&
      curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
      tar zxvf "${KREW}.tar.gz" &&
      ./"${KREW}" install krew
    )
    echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.zshrc
fi

kubectl krew install node-shell
kubectl krew install argo-rollouts

# Node.js tools
echo "Installing Node.js tools..."
npm install -g bunyan

# Service mesh
echo "Installing service mesh tools..."
brew install istioctl

# Container images
echo "Pulling required container images..."
docker pull nicolaka/netshoot:latest
docker pull busybox:latest

echo "✅ All dependencies installed!"
```

### Manual Installation

```bash
# macOS with Homebrew
brew install kubectl stern dive jq watch trivy helm fluxcd/tap/flux argocd istioctl

# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y kubectl jq
# Install other tools from their respective sources

# Install kubectl plugins via krew
kubectl krew install node-shell argo-rollouts

# Install Node.js tools
npm install -g bunyan

# Install Helm plugins
helm plugin install https://github.com/databus23/helm-diff
```

---

## Plugin Categories

## 🔧 DEBUGGING & TROUBLESHOOTING

### Debug Container (`Shift-D`)
**Description**: Attaches a debug container to an existing pod for troubleshooting
**Scope**: containers
**Dependencies**: kubectl 1.18+ (requires ephemeral containers support)
**Danger Level**: High (modifies pod)

#### Usage
```bash
# Navigate to a container in k9s and press Shift-D
# Confirms before executing:
kubectl debug -it -n=$NAMESPACE $POD --target=$NAME --image=nicolaka/netshoot:v0.13 --share-processes -- bash
```

#### Real-World Examples
1. **Network Troubleshooting**:
   ```bash
   # Inside debug container
   # Check DNS resolution
   nslookup kubernetes.default
   dig myservice.mynamespace.svc.cluster.local

   # Test connectivity
   curl http://myservice:8080/health
   nc -zv myservice 8080

   # Capture traffic
   tcpdump -i any -nn host myservice
   ```

2. **Process Inspection**:
   ```bash
   # View processes in target container
   ps aux
   # Check open files
   lsof -p 1
   # View network connections
   netstat -tulpn
   ```

3. **File System Analysis**:
   ```bash
   # Check disk usage
   df -h
   # Find large files
   find / -size +100M -type f 2>/dev/null
   ```

---

## 📊 LOGS & MONITORING

### Stern Multi-Pod Logs (`Ctrl-L`)
**Description**: Tail logs from multiple pods simultaneously with timestamps
**Scope**: pods, deployments, statefulsets
**Dependencies**: `stern` (`brew install stern`)
**Danger Level**: Safe

#### Usage
```bash
# On a deployment with 3 replicas, press Ctrl-L
stern --tail=100 --timestamps --context $CONTEXT -n $NAMESPACE $NAME
```

#### Real-World Examples
1. **Debug Distributed Application**:
   ```bash
   # Shows logs from all pods of a deployment
   # Color-coded by pod name
   # Timestamps for correlation
   stern --tail=500 --since=1h myapp
   ```

2. **Filter by Container**:
   ```bash
   stern myapp --container=nginx --tail=100
   ```

3. **Regex Filtering**:
   ```bash
   stern myapp --exclude="health|ping" --highlight="error|fail"
   ```

### Pod Metrics (`Shift-W`)
**Description**: Display CPU and memory usage for pod containers
**Scope**: pods
**Dependencies**: Metrics Server installed in cluster
**Danger Level**: Safe

#### Usage
```bash
kubectl top pod -n $NAMESPACE $NAME --containers
```

#### Example Output
```
NAME                     CPU(cores)   MEMORY(bytes)
nginx-abc123             10m          128Mi
├─ nginx                 8m           100Mi
└─ sidecar              2m           28Mi
```

### Show Events (`Shift-E`)
**Description**: Display Kubernetes events for any resource
**Scope**: all resources
**Dependencies**: kubectl
**Danger Level**: Safe

#### Common Event Types
- **Pod Events**: ImagePullBackOff, CrashLoopBackOff, OOMKilled
- **Node Events**: NotReady, DiskPressure, MemoryPressure
- **PVC Events**: ProvisioningFailed, WaitForFirstConsumer
- **Deployment Events**: ReplicaSetUpdated, ScalingReplicaSet

### Parse JSON Logs (`j`)
**Description**: Format JSON structured logs for readability
**Scope**: pods, containers
**Dependencies**: `jq` (`brew install jq`)
**Danger Level**: Safe

#### Usage Examples
```bash
# Basic pretty-print
kubectl logs $POD | jq '.'

# Filter by log level
kubectl logs $POD | jq 'select(.level == "error")'

# Extract specific fields
kubectl logs $POD | jq '{time: .timestamp, msg: .message, level: .level}'
```

### Bunyan Log Formatter (`Ctrl-B`)
**Description**: Format Node.js Bunyan JSON logs
**Scope**: pods, containers
**Dependencies**: `bunyan` (`npm install -g bunyan`)
**Danger Level**: Safe

#### Usage
```bash
kubectl logs $POD | bunyan
# Output formatted with colors, levels, and timestamps
```

---

## ✏️ EDITING & CONFIGURATION

### Edit in Neovim (`Ctrl-O`)
**Description**: Open resource YAML in Neovim for viewing/editing
**Scope**: all resources
**Dependencies**: `nvim` installed locally
**Danger Level**: Safe (read-only by default)

#### Usage Tips
1. **View Complex Resources**:
   - ConfigMaps with multiple files
   - Complex Deployment specs
   - Service mesh configurations

2. **Local Editing Workflow**:
   ```bash
   # Export to file
   kubectl get deployment myapp -o yaml > myapp.yaml
   # Edit in nvim
   nvim myapp.yaml
   # Apply changes
   kubectl apply -f myapp.yaml
   ```

### Copy YAML to Clipboard (`Ctrl-Y`)
**Description**: Copy complete resource YAML to system clipboard
**Scope**: all resources
**Dependencies**: `pbcopy` (macOS) or `xclip` (Linux)
**Danger Level**: Safe

#### Use Cases
1. **Backup Configurations**: Copy before making changes
2. **GitOps Workflow**: Copy to commit to Git repository
3. **Share Configurations**: Copy to share with team
4. **Template Creation**: Copy existing resource as template

---

## 🐳 CONTAINER OPERATIONS

### Bash Shell (`b`)
**Description**: Execute bash shell in container
**Scope**: pods, containers
**Dependencies**: Container must have `bash`
**Danger Level**: Safe (unless you modify files)

#### Enhanced Environment Setup
The plugin automatically sets up:
- `TERM=xterm-256color` for proper terminal colors
- `EDITOR` preference: nvim > vim > vi
- Proper bash initialization

#### Common Tasks
1. **Check Application Config**:
   ```bash
   cat /etc/myapp/config.yaml
   env | grep MY_APP
   ```

2. **Debug File Permissions**:
   ```bash
   ls -la /app
   stat /data/file.txt
   ```

3. **Test Internal Connectivity**:
   ```bash
   curl http://localhost:8080/health
   wget -O- http://backend-service:3000
   ```

### Shell with sh (`F5`)
**Description**: Execute sh shell (for Alpine/minimal containers)
**Scope**: pods, containers
**Dependencies**: Container must have `sh`
**Danger Level**: Safe

#### When to Use
- Alpine-based containers
- Distroless containers with shell
- Minimal containers without bash

### Shell + Install Neovim (`F6`)
**Description**: Attempts to install neovim before shell access
**Scope**: pods, containers
**Dependencies**: Container with package manager
**Danger Level**: Moderate (installs packages)

#### Supported Package Managers
- **Debian/Ubuntu**: `apt-get install neovim`
- **Alpine**: `apk add neovim`
- **RHEL/CentOS**: `yum install neovim`

### Dive Image Analysis (`d`)
**Description**: Analyze Docker image layers and find waste
**Scope**: containers
**Dependencies**: `dive` (`brew install dive`)
**Danger Level**: Safe

#### What to Look For
1. **Large Layers**: Files that can be optimized
2. **Duplicate Files**: Same file in multiple layers
3. **Deleted Files**: Files deleted in later layers (still take space)
4. **Package Manager Cache**: Uncleaned apt/yum cache

#### Optimization Tips
```dockerfile
# Bad - creates large layer
RUN apt-get update && apt-get install -y package
RUN rm -rf /var/lib/apt/lists/*

# Good - single layer
RUN apt-get update && \
    apt-get install -y package && \
    rm -rf /var/lib/apt/lists/*
```

### Trivy Security Scan (`Shift-V`)
**Description**: Scan container image for vulnerabilities
**Scope**: containers
**Dependencies**: `trivy` (`brew install aquasecurity/trivy/trivy`)
**Danger Level**: Safe

#### Severity Levels
- **CRITICAL**: Immediate action required
- **HIGH**: Should be fixed soon
- **MEDIUM**: Plan to fix
- **LOW**: Nice to fix
- **UNKNOWN**: Insufficient data

#### Example Output
```
nginx:latest (debian 11.5)
Total: 142 (HIGH: 2, CRITICAL: 1)

┌─────────────┬────────────────┬──────────┬───────────────────┬─────────────────────┐
│   Library   │ Vulnerability  │ Severity │ Installed Version │     Fixed Version   │
├─────────────┼────────────────┼──────────┼───────────────────┼─────────────────────┤
│ openssl     │ CVE-2022-1234  │ CRITICAL │ 1.1.1n            │ 1.1.1q             │
└─────────────┴────────────────┴──────────┴───────────────────┴─────────────────────┘
```

---

## 🚀 DEPLOYMENT OPERATIONS

### Restart Deployment (`Shift-R`)
**Description**: Trigger rolling restart without config changes
**Scope**: deployments, statefulsets, daemonsets
**Dependencies**: kubectl 1.15+
**Danger Level**: Moderate (causes pod recreation)

#### When to Use
1. **Pick up ConfigMap/Secret changes** (if not auto-reloaded)
2. **Clear application cache/state**
3. **Apply resource limit changes**
4. **Recover from transient errors**

#### What Happens
```bash
kubectl rollout restart deployment/myapp
# Adds annotation: kubectl.kubernetes.io/restartedAt: "2024-01-20T10:30:00Z"
# Triggers rolling update with same spec
```

### Scale Deployment (`Shift-S`)
**Description**: Interactively change replica count
**Scope**: deployments, statefulsets
**Dependencies**: kubectl
**Danger Level**: Moderate

#### Scaling Scenarios
1. **Scale Up for Load**:
   ```bash
   # Peak traffic - scale from 3 to 10 replicas
   Enter replica count: 10
   ```

2. **Scale Down for Maintenance**:
   ```bash
   # Maintenance window - reduce to 1 replica
   Enter replica count: 1
   ```

3. **Scale to Zero**:
   ```bash
   # Complete pause (keeps configuration)
   Enter replica count: 0
   ```

---

## 🌐 NETWORKING

### Port Forward (`Shift-K`)
**Description**: Forward local port to pod/service
**Scope**: pods, services
**Dependencies**: kubectl
**Danger Level**: Safe

#### Interactive Usage
```bash
# Press Shift-K on a service
Enter local:remote ports (e.g., 8080:80): 8080:3000
# Now accessible at http://localhost:8080
```

#### Common Port Forwards
```bash
# Database access
5432:5432  # PostgreSQL
3306:3306  # MySQL
27017:27017 # MongoDB

# Web services
8080:80    # HTTP
8443:443   # HTTPS
3000:3000  # Node.js apps

# Debugging
9229:9229  # Node.js debugger
5005:5005  # Java debugger
```

### Network Debug Container (`Ctrl-G`)
**Description**: Launch netshoot container with network tools
**Scope**: nodes, pods
**Dependencies**: Internet access for image pull
**Danger Level**: Safe

#### Available Tools in netshoot
- **DNS**: `dig`, `nslookup`, `host`
- **HTTP**: `curl`, `wget`, `httpie`
- **Network**: `ping`, `traceroute`, `mtr`, `iperf3`
- **Packet**: `tcpdump`, `tshark`
- **Port**: `netcat`, `socat`, `nmap`
- **TLS**: `openssl`

#### Debugging Examples
```bash
# Test service discovery
nslookup myservice.default.svc.cluster.local

# Check connectivity with timing
curl -w "@curl-format.txt" -o /dev/null -s http://myservice

# Test load balancing
for i in {1..10}; do curl http://myservice/hostname; done

# Debug TLS
openssl s_client -connect myservice:443 -showcerts
```

### TCP Dump (`Ctrl-T`)
**Description**: Capture network packets
**Scope**: pods
**Dependencies**: `tcpdump` in container
**Danger Level**: Safe

#### Capture Examples
```bash
# HTTP traffic
tcpdump -i any -nn -s0 -A 'tcp port 80'

# Specific host
tcpdump -i any host 10.0.0.5

# DNS queries
tcpdump -i any -nn port 53

# Write to file for analysis
tcpdump -i any -w /tmp/capture.pcap
```

### DNS Trace (`Ctrl-N`)
**Description**: Debug DNS resolution
**Scope**: pods
**Dependencies**: DNS tools in container
**Danger Level**: Safe

#### DNS Debugging
```bash
# Standard lookups
nslookup kubernetes.default
nslookup myservice.mynamespace.svc.cluster.local

# Check search domains
cat /etc/resolv.conf

# Trace resolution
dig +trace google.com
```

---

## 🔄 FLUX GITOPS

### Toggle Flux Suspend (`Shift-G`)
**Description**: Suspend or resume Flux reconciliation
**Scope**: helmreleases
**Dependencies**: `flux` CLI installed
**Danger Level**: Moderate (stops automation)

#### Usage Scenarios
1. **During Incident Response**:
   ```bash
   # Suspend to prevent auto-updates during debugging
   flux suspend helmrelease myapp -n production
   # Fix issue manually
   # Resume when fixed
   flux resume helmrelease myapp -n production
   ```

2. **Maintenance Window**:
   ```bash
   # Suspend all in namespace
   flux suspend helmrelease --all -n production
   ```

### Flux Reconcile (`Shift-X`)
**Description**: Force immediate reconciliation
**Scope**: gitrepositories, helmreleases, kustomizations
**Dependencies**: `flux` CLI
**Danger Level**: Safe

#### When to Use
- After pushing changes to Git
- To retry after fixing errors
- To apply changes immediately (bypass interval)

---

## 👀 OBSERVABILITY

### Watch Resource (`w`)
**Description**: Auto-refresh resource view every 2 seconds
**Scope**: all resources
**Dependencies**: `watch` command
**Danger Level**: Safe

#### Monitoring Scenarios
```bash
# Watch deployment rollout
watch kubectl get pods -l app=myapp

# Monitor node resources
watch kubectl top nodes

# Track job completion
watch kubectl get jobs
```

### Get All Resources (`Shift-A`)
**Description**: List all resources in namespace
**Scope**: namespaces
**Dependencies**: kubectl
**Danger Level**: Safe

#### What's Included
- Pods, Services, Deployments
- ConfigMaps, Secrets
- Ingresses, NetworkPolicies
- ServiceAccounts, Roles
- PVCs, Jobs, CronJobs

---

## 🖥️ NODE OPERATIONS

### Node Shell (`Shift-U`)
**Description**: SSH-like access to node
**Scope**: nodes
**Dependencies**: `kubectl-node-shell` plugin
**Danger Level**: High (root access to node)

#### Installation
```bash
kubectl krew install node-shell
```

#### Common Node Tasks
```bash
# Check kubelet logs
journalctl -u kubelet -f

# View system resources
top
df -h
free -h

# Check container runtime
crictl ps
docker ps

# Network interfaces
ip addr show
```

### Drain Node (`Shift-D` on nodes)
**Description**: Safely evict pods before maintenance
**Scope**: nodes
**Dependencies**: kubectl
**Danger Level**: High (evacuates pods)

#### Drain Process
```bash
kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data
# What happens:
# 1. Marks node as unschedulable
# 2. Evicts all pods (except daemonsets)
# 3. Waits for pod termination
# 4. Node ready for maintenance
```

#### After Maintenance
```bash
# Make node schedulable again
kubectl uncordon node-1
```

---

## ⚓ HELM OPERATIONS

### Show Helm Values (`v`)
**Description**: Display deployed Helm values in Neovim
**Scope**: helmreleases
**Dependencies**: `helm` 3.x
**Danger Level**: Safe

#### View Options
```bash
# User values only (what you provided)
helm get values myrelease

# All values (including defaults)
helm get values myrelease --all

# Specific revision
helm get values myrelease --revision 2
```

### Helm Diff (`Shift-H`)
**Description**: Preview changes before upgrade
**Scope**: helmreleases
**Dependencies**: `helm-diff` plugin
**Danger Level**: Safe

#### Installation
```bash
helm plugin install https://github.com/databus23/helm-diff
```

#### Diff Scenarios
```bash
# Against new chart version
helm diff upgrade myrelease repo/chart --version 2.0.0

# Against values file changes
helm diff upgrade myrelease . -f new-values.yaml

# Color-coded output:
# - Red: Removed
# + Green: Added
# ~ Yellow: Changed
```

### Purge Helm Release (`Ctrl-P`)
**Description**: Complete removal including history
**Scope**: helmreleases
**Dependencies**: helm
**Danger Level**: **DANGEROUS** (data loss)

#### What Gets Deleted
- All Kubernetes resources
- Helm release history
- Associated secrets
- PVCs (if not retained)

#### Safer Alternative
```bash
# Uninstall but keep history
helm uninstall myrelease --keep-history

# Can be rolled back if needed
helm rollback myrelease
```

### Helm Rollback (`Ctrl-H`)
**Description**: Rollback to previous release
**Scope**: helmreleases
**Dependencies**: helm
**Danger Level**: Moderate

#### Rollback Options
```bash
# To previous version
helm rollback myrelease

# To specific revision
helm rollback myrelease 3

# Check history first
helm history myrelease
```

---

## 🚢 ARGOCD INTEGRATION

### Sync ArgoCD App (`Shift-Y`)
**Description**: Force sync from Git repository
**Scope**: ArgoCD Applications
**Dependencies**: `argocd` CLI, authenticated
**Danger Level**: Moderate (applies changes)

#### Prerequisites
```bash
# Login to ArgoCD
argocd login argocd.example.com
```

#### Sync Options
```bash
# Normal sync
argocd app sync myapp

# Force sync (overwrites manual changes)
argocd app sync myapp --force

# Prune resources not in Git
argocd app sync myapp --prune

# Specific resource
argocd app sync myapp --resource apps/Deployment:mydeployment
```

### ArgoCD Diff (`Ctrl-D`)
**Description**: Show differences between Git and cluster
**Scope**: ArgoCD Applications
**Dependencies**: `argocd` CLI
**Danger Level**: Safe

#### Understanding Diff Output
```diff
# Resources to be created
+ apiVersion: v1
+ kind: Service

# Resources to be updated
~ spec:
~   replicas: 3  # was 1

# Resources to be deleted (if prune enabled)
- apiVersion: v1
- kind: ConfigMap
```

---

## 🔒 CERTIFICATE MANAGEMENT

### Check Certificate (`Shift-C`)
**Description**: Verify certificate readiness
**Scope**: cert-manager Certificate resources
**Dependencies**: cert-manager installed
**Danger Level**: Safe

#### Certificate States
- **Ready**: Certificate issued and valid
- **Issuing**: Certificate being requested
- **Failed**: Issuance failed (check events)

#### Common Issues
```bash
# Check certificate status
kubectl describe certificate mycert

# Common problems:
# - DNS01 challenge failed: DNS provider issues
# - HTTP01 challenge failed: Ingress misconfiguration
# - Rate limited: Let's Encrypt limits exceeded
```

### Force Certificate Renewal (`Ctrl-C`)
**Description**: Trigger immediate renewal
**Scope**: cert-manager Certificates
**Dependencies**: cert-manager
**Danger Level**: Moderate

#### When to Force Renewal
1. **Testing renewal process**
2. **After fixing configuration**
3. **Updating certificate domains**

#### Manual Renewal
```bash
# Delete the secret to trigger reissuance
kubectl delete secret mycert-tls
# cert-manager will recreate it
```

---

## 📈 RESOURCE OPTIMIZATION

### Resource Recommendations (`Shift-Q`)
**Description**: Compare actual usage vs requests/limits
**Scope**: pods
**Dependencies**: Metrics Server, `jq`
**Danger Level**: Safe

#### Analysis Output
```bash
Analyzing resource usage for nginx-abc123...

CONTAINER   CPU(cores)  MEMORY(bytes)
nginx       15m         256Mi

Current requests/limits:
{
  "name": "nginx",
  "requests": { "cpu": "100m", "memory": "128Mi" },
  "limits": { "cpu": "500m", "memory": "512Mi" }
}
```

#### Optimization Guidelines
1. **CPU**: Request = P95 usage, Limit = P99 usage
2. **Memory**: Request = P95 usage, Limit = max observed + 20%
3. **Leave headroom** for spikes
4. **Consider** Vertical Pod Autoscaler (VPA)

---

## 🔨 ADVANCED TROUBLESHOOTING

### Remove Finalizers (`Ctrl-F`)
**Description**: Force removal of stuck resources
**Scope**: all resources
**Dependencies**: kubectl
**Danger Level**: **DANGEROUS** (bypasses cleanup)

#### When Resources Get Stuck
```bash
# Check finalizers
kubectl get pod stuck-pod -o json | jq '.metadata.finalizers'

# Common finalizers:
# - kubernetes.io/pvc-protection
# - foregroundDeletion
# - orphan
```

#### Safe Removal Process
1. **Understand why** it's stuck
2. **Manually cleanup** dependent resources
3. **Then remove** finalizer
4. **Monitor** for orphaned resources

### Debug PVC (`Shift-P`)
**Description**: Mount PVC in debug container
**Scope**: persistentvolumeclaims
**Dependencies**: kubectl
**Danger Level**: Safe

#### PVC Debugging Tasks
```bash
# In debug container with PVC mounted at /pvc
# Check contents
ls -la /pvc

# Verify permissions
stat /pvc

# Test write access
echo "test" > /pvc/test.txt

# Check disk usage
du -sh /pvc/*

# Recover data
tar czf /tmp/backup.tar.gz /pvc/*
```

---

## ⏰ JOB MANAGEMENT

### Toggle CronJob (`Ctrl-J`)
**Description**: Suspend/resume scheduled execution
**Scope**: cronjobs
**Dependencies**: kubectl
**Danger Level**: Moderate

#### Suspension Scenarios
1. **During Maintenance**:
   ```bash
   # Suspend
   kubectl patch cronjob backup -p '{"spec":{"suspend":true}}'
   # Resume after maintenance
   kubectl patch cronjob backup -p '{"spec":{"suspend":false}}'
   ```

2. **Debugging Failed Jobs**:
   ```bash
   # Suspend to prevent new jobs
   # Debug existing job
   # Fix and resume
   ```

---

## 🔌 SPECIALIZED INTEGRATIONS

### KEDA Autoscaling

#### Toggle KEDA ScaledObject (`Ctrl-K`)
**Description**: Pause/resume KEDA autoscaling
**Scope**: scaledobjects
**Dependencies**: KEDA operator installed
**Danger Level**: Moderate

##### Usage
```bash
# Pause scaling
kubectl annotate scaledobject myapp keda.sh/paused=true

# Resume scaling
kubectl annotate scaledobject myapp keda.sh/paused-
```

##### When to Pause KEDA
- During performance testing
- When debugging scaling issues
- During maintenance windows

### External Secrets Operator

#### Refresh External Secret (`Ctrl-E`)
**Description**: Force synchronization with secret store
**Scope**: externalsecrets
**Dependencies**: External Secrets Operator
**Danger Level**: Safe

##### Common Secret Stores
- AWS Secrets Manager
- HashiCorp Vault
- Azure Key Vault
- Google Secret Manager

##### Force Refresh Scenarios
```bash
# After updating secret in vault
kubectl annotate externalsecret mysecret force-sync="-" --overwrite

# Check sync status
kubectl get externalsecret mysecret
```

### Crossplane

#### Crossplane Resource Status (`Ctrl-X`)
**Description**: Check managed resource conditions
**Scope**: Crossplane managed resources
**Dependencies**: Crossplane, `jq`
**Danger Level**: Safe

##### Understanding Conditions
```json
{
  "type": "Ready",
  "status": "True",
  "reason": "Available",
  "message": "Resource is available for use"
}
```

##### Common Conditions
- **Ready**: Resource is fully provisioned
- **Synced**: In sync with cloud provider
- **Creating**: Being provisioned
- **Deleting**: Being removed

### Istio Service Mesh

#### Proxy Configuration (`Ctrl-U`)
**Description**: View Envoy sidecar configuration
**Scope**: pods with Istio sidecar
**Dependencies**: `istioctl`
**Danger Level**: Safe

##### Configuration Types
```bash
# All configurations
istioctl proxy-config all pod-name

# Specific configs:
istioctl proxy-config cluster pod-name    # Upstream clusters
istioctl proxy-config listener pod-name   # Listeners
istioctl proxy-config route pod-name      # Routes
istioctl proxy-config endpoint pod-name   # Endpoints
```

### Argo Rollouts

#### Promote Rollout (`Ctrl-R`)
**Description**: Advance progressive deployment
**Scope**: Argo Rollout resources
**Dependencies**: `kubectl-argo-rollouts` plugin
**Danger Level**: Moderate

##### Progressive Delivery Strategies
1. **Canary**:
   ```bash
   # Promotes from 20% to 40% traffic
   kubectl-argo-rollouts promote myapp
   ```

2. **Blue-Green**:
   ```bash
   # Switches all traffic to new version
   kubectl-argo-rollouts promote myapp
   ```

#### Abort Rollout (`Ctrl-A`)
**Description**: Stop and rollback deployment
**Scope**: Argo Rollout resources
**Dependencies**: `kubectl-argo-rollouts` plugin
**Danger Level**: High (rolls back)

##### When to Abort
- Error rate spike detected
- Performance degradation
- Failed smoke tests
- Customer complaints

---

## Common Troubleshooting Scenarios

### Scenario 1: Pod Won't Start

1. **Check Events** (`Shift-E`):
   - ImagePullBackOff → Registry/credentials issue
   - CrashLoopBackOff → Application failing
   - Pending → Resource constraints

2. **Check Logs** (`Ctrl-L`):
   - Application errors
   - Configuration issues
   - Missing dependencies

3. **Debug Container** (`Shift-D`):
   - Test connectivity
   - Check file permissions
   - Verify environment

### Scenario 2: Service Unavailable

1. **Port Forward** (`Shift-K`):
   - Test if pod is working directly

2. **Network Debug** (`Ctrl-G`):
   - Test DNS resolution
   - Check connectivity
   - Verify endpoints

3. **Check Service**:
   - Correct selector labels
   - Right ports
   - Endpoints present

### Scenario 3: High Memory Usage

1. **Pod Metrics** (`Shift-W`):
   - Current usage vs limits

2. **Resource Recommendations** (`Shift-Q`):
   - Compare with actual usage

3. **Container Shell** (`b`):
   - Check for memory leaks
   - View process memory

### Scenario 4: Stuck Deletion

1. **Check Finalizers** (`Ctrl-F`):
   - List current finalizers
   - Understand dependencies

2. **Force Delete**:
   ```bash
   kubectl delete pod stuck-pod --grace-period=0 --force
   ```

3. **Remove Finalizers** (last resort):
   - Use `Ctrl-F` carefully

### Scenario 5: Certificate Issues

1. **Check Certificate** (`Shift-C`):
   - Ready status
   - Expiration date

2. **Check Events** (`Shift-E`):
   - Challenge failures
   - DNS issues

3. **Force Renewal** (`Ctrl-C`):
   - After fixing issues

---

## Tips & Best Practices

### Safety Guidelines

1. **Always confirm** dangerous operations
2. **Check events first** (`Shift-E`) before diving deeper
3. **Use port-forward** (`Shift-K`) to test services safely
4. **Take backups** before making changes:
   ```bash
   kubectl get resource -o yaml > backup.yaml
   ```

### Performance Tips

1. **Use Stern** (`Ctrl-L`) instead of multiple log commands
2. **Watch resources** (`w`) during deployments
3. **Use JSON parsing** (`j`) for structured logs
4. **Port-forward** (`Shift-K`) runs in background

### Debugging Workflow

1. **Start with Events** → `Shift-E`
2. **Check Logs** → `Ctrl-L`
3. **View Metrics** → `Shift-W`
4. **Interactive Debug** → `Shift-D` or `b`
5. **Network Test** → `Ctrl-G`

### Plugin Combinations

1. **Deployment Update**:
   - `v` - Check current values
   - `Shift-H` - Preview changes
   - `Shift-R` - Apply restart

2. **Troubleshooting Pod**:
   - `Shift-E` - Check events
   - `Ctrl-L` - View logs
   - `b` - Shell access
   - `Shift-D` - Debug container

3. **Security Audit**:
   - `Shift-V` - Scan image
   - `d` - Analyze layers
   - `Ctrl-O` - Review security policies

### Keyboard Shortcuts Memory Aids

- **Letters** (`b`, `d`, `j`, `v`, `w`) - Basic operations
- **Shift+Letter** - More powerful operations
- **Ctrl+Letter** - Advanced/specialized operations
- **Function Keys** - Shell variations

### Custom Plugin Ideas

You can add your own plugins to `~/.config/k9s/plugins.yaml`:

```yaml
# Example: Quick backup
backup-resource:
  shortCut: Shift-B
  description: Backup resource
  scopes:
    - all
  command: bash
  background: false
  args:
    - -c
    - "kubectl get $RESOURCE_NAME -n $NAMESPACE -o yaml > ~/k8s-backups/$(date +%Y%m%d-%H%M%S)-$NAME.yaml && echo 'Backed up to ~/k8s-backups/'"
```

---

## Quick Install All Dependencies

```bash
# Run this to install everything needed for all plugins
curl -sSL https://raw.githubusercontent.com/yourusername/dotfiles/main/k9s-plugin-deps.sh | bash
```

---

## Plugin Reference by Resource Type

### Pods
- `b` - Bash shell
- `F5` - sh shell
- `F6` - Shell + nvim
- `Ctrl-L` - Logs with Stern
- `j` - JSON logs
- `Shift-W` - Metrics
- `Shift-E` - Events
- `Shift-K` - Port forward
- `Shift-D` - Debug container
- `Ctrl-T` - tcpdump
- `Ctrl-N` - DNS trace

### Deployments
- `Shift-R` - Restart
- `Shift-S` - Scale
- `Ctrl-L` - Multi-pod logs
- `Shift-E` - Events

### Services
- `Shift-K` - Port forward
- `Shift-E` - Events

### Nodes
- `Shift-U` - Node shell
- `Shift-D` - Drain node
- `Ctrl-G` - Network debug

### ConfigMaps/Secrets
- `Ctrl-O` - Edit in nvim
- `Ctrl-Y` - Copy to clipboard

### HelmReleases
- `v` - Show values
- `Shift-H` - Diff
- `Ctrl-P` - Purge
- `Ctrl-H` - Rollback
- `Shift-G` - Toggle Flux

### PVCs
- `Shift-P` - Debug mount

### CronJobs
- `Ctrl-J` - Toggle suspend

---

This guide covers all 49 k9s plugins configured in your system. Each plugin is designed for specific Kubernetes troubleshooting and management scenarios. Remember to install the required dependencies for the plugins you plan to use most frequently.