# kubecui Integration Plan for Dotfiles

## Executive Summary

This document analyzes [kubecui](https://github.com/pymag09/kubecui) features and identifies valuable integrations for your Fish shell dotfiles, with the goal of replacing k9s with a pure kubectl + FZF workflow.

**Key Decision**: User wants to move away from k9s → kubecui's approach aligns perfectly (kubectl-native with FZF enhancements)

**Keybinding Choice**: Ctrl-based keybindings (macOS F-keys have system conflicts)

**Cluster Environment**: 3-5 clusters (dev/staging/prod typical setup with AKS)

---

## Current Dotfiles Setup (What You Already Have)

### Kubernetes Tools Installed
- `kubectl`, `kubectx`, `kubens`, `kubie`, `stern`
- `k9s` (want to phase out)
- `helm`, `kustomize`, `velero`, `argocd`, `flux`
- Local: `minikube`, `k3d`, `kind`

### Fish Shell Integration
- **780+ kubectl abbreviations** (`conf.d/kubectl-aliases.fish`)
- **FZF integration** (`conf.d/kubectl-fzf.fish`) - intercepts `kubectl get` for interactive selection
- **YAML preview** with bat syntax highlighting
- **Custom functions**: `k8s-mount.fish`, `stern.fish`, `knvim.fish`
- **k9s config**: Multiple cluster configs, Tokyo Night theme, plugins

### Current FZF Keybindings
- `Ctrl-D` / `Ctrl-U` - Page down/up in preview
- `Ctrl-Y` - Open full YAML in bat
- `Ctrl-E` - Describe resource
- `Ctrl-/` - Toggle preview window

---

## kubecui Features Analysis

### Features You DON'T Need (Already Have Better)
| Feature | kubecui | Your Setup | Verdict |
|---------|---------|------------|---------|
| `k` alias | Single function | 780+ abbreviations | ✅ Keep yours |
| FZF resource selection | Basic | Already implemented | ✅ Keep yours |
| YAML preview | Basic | bat highlighting | ✅ Keep yours |

### Features Worth Integrating

#### 1. FZF Action Keybindings (HIGH VALUE)
**What**: Instant actions from within FZF selection without typing follow-up commands

**kubecui F-keys → macOS Ctrl alternatives**:
| Action | kubecui | Proposed | Description |
|--------|---------|----------|-------------|
| Explain | F1 | `Ctrl-A` | Show API docs for resource type |
| View YAML | F3 | `Ctrl-Y` | Open full YAML in editor (already have) |
| Edit | F4 | `Ctrl-O` | `kubectl edit` selected resource |
| Search describe | F5 | `Ctrl-S` | Fuzzy search within describe output |
| Port-forward | F6 | `Ctrl-F` | Start port-forward to pod |
| Debug container | F7 | `Ctrl-B` | Attach ephemeral debug container |
| Delete | F8 | `Ctrl-X` | Delete with confirmation |
| Clone | Ctrl+6 | `Ctrl-K` | Duplicate resource with random suffix |
| Reload | Ctrl-R | `Ctrl-R` | Refresh FZF list (keep) |

**Implementation**: Modify `kubectl-fzf.fish` to add `--bind` options to FZF calls

---

#### 2. Interactive Port-Forward Helper (HIGH VALUE)
**What**: FZF-based pod + port selection with automatic local port finding

**Current workflow**:
```bash
kubectl get pod -o yaml | grep containerPort  # manual
kubectl port-forward pod/name 8080:8080       # manual typing
```

**kubecui workflow**:
```bash
k pf  # or k port-forward
→ FZF: Select pod (preview shows containers & ports)
→ FZF: Select container port (8080, 9090, etc.)
→ Auto-finds available local port
→ Starts forwarding, shows URL
```

**Implementation**: New Fish function `kpf.fish`
```fish
function kpf --description "Interactive kubectl port-forward"
    # 1. Select pod via FZF
    # 2. Get container ports from pod spec
    # 3. Select port via FZF
    # 4. Find available local port
    # 5. Execute port-forward
end
```

---

#### 3. Node Shell / Ephemeral Debug Container (MEDIUM VALUE)
**What**: Spawn privileged Alpine container on node for node-level debugging

**Use case**: Debug node issues in managed K8s (AKS/EKS/GKE) without SSH access

**Command**:
```bash
kubectl debug node/<node-name> -it --image=alpine:3.13 -- \
    nsenter -t 1 -m -u -i -n -p -- /bin/bash
```

**Implementation**: New Fish function `knode-shell.fish`
```fish
function knode-shell --description "Get shell on Kubernetes node"
    set node (kubectl get nodes -o name | fzf --prompt="Select node: ")
    kubectl debug $node -it --image=alpine:3.13 -- \
        nsenter -t 1 -m -u -i -n -p -- /bin/bash
end
```

---

#### 4. Secret Base64 Decode in Preview (MEDIUM VALUE)
**What**: Auto-decode base64 secrets in FZF preview pane

**Current**: See `data.password: c2VjcmV0MTIz`
**With feature**: See `data.password: secret123`

**Implementation**: Modify preview command in FZF to pipe through decoder for secrets:
```fish
# In FZF preview for secrets
kubectl get secret $name -o yaml | yq '.data | map_values(@base64d)'
```

---

#### 5. Interactive Scale Helper (LOW VALUE)
**What**: FZF selector for replica count (0-100)

**Implementation**: Fish function `kscale.fish`
```fish
function kscale --description "Interactive replica scaling"
    set resource (kubectl get deploy,sts -o name | fzf)
    set replicas (seq 0 20 | fzf --prompt="Replicas: ")
    kubectl scale $resource --replicas=$replicas
end
```

---

#### 6. FZF Context/Namespace Switch (MEDIUM VALUE)
**What**: Replace kubectx/kubens with FZF-integrated versions for consistent UX

**Implementation**: Fish functions `kctx.fish` and `kns.fish`
```fish
function kctx --description "FZF context switcher"
    set ctx (kubectl config get-contexts -o name | fzf --preview 'kubectl config view --context={}')
    kubectl config use-context $ctx
end

function kns --description "FZF namespace switcher"
    set ns (kubectl get ns -o name | cut -d/ -f2 | fzf)
    kubectl config set-context --current --namespace=$ns
end
```

---

#### 7. tmux Multi-Cluster Sessions (OPTIONAL - k9s Replacement)
**What**: Pre-configured tmux sessions with cluster-specific windows

**NORMAL Mode**: 1 session, 3 windows (dev/stg/prod)
**DARK_SIDE Mode**: 3 sessions × 10 windows each (resource-specific)

**Window Layout (per cluster)**:
| Window | Resource | Auto-command |
|--------|----------|--------------|
| 0 | pods | `k get pods -A` |
| 1 | deployments | `k get deploy -A` |
| 2 | logs | (empty for tailing) |
| 3 | ingress | `k get ingress -A` |
| 4 | configmaps | `k get cm -A` |
| 5 | secrets | `k get secrets -A` |
| 6 | services | `k get svc -A` |
| 7 | pv | `k get pv` |
| 8 | pvc | `k get pvc -A` |
| 9 | custom | (empty) |

**Navigation**:
- `Ctrl-b s` → Switch between cluster sessions
- `Ctrl-b 0-9` → Jump to resource window
- `Ctrl-b w` → Window picker

**Implementation**: Fish function `k8s-session.fish` + tmuxp YAML templates

**Trade-offs**:
- Pro: Dedicated views like k9s, cluster isolation, persistent sessions
- Con: Heavy (30 windows), may conflict with existing tmux workflow
- Alternative: Lighter version with 3-4 windows per cluster

---

## Recommended Implementation Order

### Phase 1: Core FZF Enhancements (Immediate Value)
1. **FZF Action Keybindings** - Enhance existing `kubectl-fzf.fish`
2. **Port-Forward Helper** - New `kpf.fish` function
3. **FZF Context/Namespace** - New `kctx.fish`, `kns.fish`

### Phase 2: Helper Functions
4. **Node Shell** - New `knode-shell.fish`
5. **Scale Helper** - New `kscale.fish`
6. **Secret Decode Preview** - Modify FZF preview logic

### Phase 3: tmux Integration (Optional k9s Replacement)
7. **tmux Session Manager** - `k8s-session.fish` + templates
8. **Cluster Profiles** - YAML configs for your AKS clusters

---

## Files to Create/Modify

### New Files
```
.config/fish/functions/
├── kpf.fish              # Port-forward helper
├── kctx.fish             # FZF context switcher
├── kns.fish              # FZF namespace switcher
├── knode-shell.fish      # Node debug shell
├── kscale.fish           # Scale helper
└── k8s-session.fish      # tmux session manager (optional)

.config/tmux/k8s-profiles/    # (optional)
├── dev.yaml
├── staging.yaml
└── prod.yaml
```

### Files to Modify
```
.config/fish/conf.d/kubectl-fzf.fish   # Add Ctrl-based keybindings
.config/fish/functions/_fifc_kubectl_preview.fish  # Secret decode
```

---

## Keybinding Reference (Ctrl-based for macOS)

### FZF kubectl Keybindings (Proposed)
| Key | Action | Implementation |
|-----|--------|----------------|
| `Ctrl-A` | API explain | `kubectl explain {resource-type}` |
| `Ctrl-Y` | View YAML | Open in `$EDITOR` or bat (existing) |
| `Ctrl-O` | Edit resource | `kubectl edit {resource}` |
| `Ctrl-S` | Search describe | `kubectl describe \| fzf` |
| `Ctrl-F` | Port-forward | Trigger `kpf` function |
| `Ctrl-B` | Debug container | `kubectl debug` |
| `Ctrl-X` | Delete | `kubectl delete` with confirm |
| `Ctrl-K` | Clone resource | Duplicate with suffix |
| `Ctrl-R` | Reload | Refresh FZF list (existing) |
| `Ctrl-/` | Toggle preview | Change preview size (existing) |

### Existing FZF Keybindings (Preserve)
| Key | Action |
|-----|--------|
| `Ctrl-D` / `Ctrl-U` | Page down/up preview |
| `Ctrl-E` | Describe resource |
| `Tab` | Select multiple |

---

## Dependencies

### Required (Already Installed)
- `fzf` - Fuzzy finder
- `kubectl` - Kubernetes CLI
- `bat` - Syntax highlighting
- `yq` - YAML processor

### Optional
- `tmux` + `tmuxp` - For session management (already have tmux)

---

## Reference Links

- [kubecui GitHub](https://github.com/pymag09/kubecui)
- [kubecui Articles](https://medium.com/@magelan09):
  - [kubectl on Steroids](https://medium.com/@magelan09/kubectl-on-steroids-there-is-life-beyond-k9s-5c214e878c83)
  - [DARK_SIDE Mode](https://medium.com/@magelan09/kubecui-enhanced-interactive-kubectl-dark-side-mode-720a1f19b0bf)
  - [Unlimited Flexibility](https://medium.com/@magelan09/unleashing-unlimited-potential-the-secret-to-kubecuis-unmatched-flexibility-4a41ba7003c1)
  - [New Shortcuts Part 3](https://medium.com/@magelan09/navigating-kubernetes-effortlessly-with-kubecui-new-shortcuts-and-features-part-3-df3ab0449518)
  - [Ephemeral Containers Part 4](https://medium.com/@magelan09/kubecui-ephemeral-containers-and-more-part-4-f069d7ebc405)
  - [Milestone Part 5](https://medium.com/@magelan09/kubecui-has-reached-its-first-big-milestone-part-5-in-the-series-of-the-articles-c520c3c33ab1)

---

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| k9s replacement | Yes | User wants to phase out k9s |
| Keybindings | Ctrl-based | macOS F-keys have system conflicts |
| tmux sessions | Optional | Useful for k9s replacement but heavy |
| Implementation | Phased | Start with high-value, add incrementally |
