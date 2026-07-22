# 12 — Cheat sheet và thuật ngữ

## 1. Application

```bash
argocd app list
argocd app get APP
argocd app get APP --refresh
argocd app get APP --hard-refresh
argocd app get APP --show-operation
argocd app manifests APP
argocd app diff APP
argocd app sync APP
argocd app sync APP --prune
argocd app wait APP --sync --health --timeout 300
argocd app history APP
argocd app terminate-op APP
```

## 2. Project, repo và cluster

```bash
argocd proj list
argocd proj get PROJECT
argocd repo list
argocd cluster list
argocd account can-i sync applications 'PROJECT/APP'
```

## 3. Kubernetes

```bash
kubectl get applications,applicationsets,appprojects -n argocd
kubectl describe application APP -n argocd
kubectl get deploy,statefulset,pod,service -n argocd
kubectl get events -n argocd --sort-by=.lastTimestamp
kubectl logs -n argocd deploy/argocd-repo-server --since=10m
kubectl logs -n argocd statefulset/argocd-application-controller --since=10m
```

## 4. Cài và truy cập

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.2/manifests/install.yaml

kubectl wait --for=condition=Available deployment --all \
  -n argocd --timeout=300s

kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd admin initial-password -n argocd
```

## 5. Thuật ngữ

| Thuật ngữ | Nghĩa thực dụng |
|---|---|
| Desired state | Manifest Argo CD render từ source/revision |
| Live state | Resource hiện có từ Kubernetes API |
| Drift | Khác biệt giữa desired và live |
| Reconcile | Vòng lặp so sánh và hội tụ state |
| Refresh | Đọc/tính lại state và diff |
| Sync | Apply desired state vào cluster |
| Prune | Xóa managed resource không còn ở desired state |
| Self-heal | Tự sync khi live drift khỏi Git |
| Health | Đánh giá workload/resource có hoạt động không |
| Revision | Branch, tag, commit SHA hoặc chart version |
| Project | Policy boundary cho app |
| Generator | Nguồn dữ liệu để ApplicationSet sinh app |
| Hook | Resource chạy theo phase sync |
| Wave | Thứ tự tương đối trong phase |
| Finalizer | Cơ chế giữ object để hoàn tất cleanup |
| Orphan resource | Resource không còn owner/tracking mong đợi |
| CMP | Config Management Plugin cho render tùy biến |

## 6. `metadata.namespace` và `destination.namespace`

```yaml
metadata:
  namespace: argocd
spec:
  destination:
    namespace: demo
```

- Application CR ở `argocd`.
- Workload ở `demo`.

## 7. Bản đồ trạng thái

| Trạng thái | Việc đầu tiên |
|---|---|
| OutOfSync | Xem diff, revision và field owner |
| Synced + Degraded | Xem resource tree, events, logs |
| ComparisonError | Xem Conditions và repo-server |
| Progressing lâu | Xem readiness, Job, hook, wave |
| Unknown | Kiểm tra repo/cluster/controller connection |

## 8. Lệnh nguy hiểm cần dừng một nhịp

```bash
argocd app sync APP --prune
kubectl delete application APP -n argocd
kubectl delete namespace argocd
```

Trước khi chạy, xác nhận:

- context;
- namespace;
- finalizer/cascade behavior;
- resource sẽ bị prune/delete;
- backup và rollback.

## 9. Tài liệu chính thức theo chủ đề

- [Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Architecture](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/)
- [Application spec](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- [Automated sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Sync phases/waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Private repositories](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/)
- [Ingress](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
- [RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- [High availability](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/)
- [Upgrade guides](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/)

## 10. Tiêu chí hoàn thành khóa học

Bạn đạt mục tiêu khi có thể tự làm và giải thích:

- [ ] Vẽ flow CI/GitOps/Argo CD/Kubernetes.
- [ ] Cài và truy cập UI trên cluster lab.
- [ ] Tạo Application UI/YAML mà không chép mù.
- [ ] Giải thích SYNC và SYNCHRONIZE.
- [ ] Dự đoán `Sync Status` và `Health Status`.
- [ ] Tạo/khôi phục drift, prune và self-heal.
- [ ] Render Kustomize/Helm trước commit.
- [ ] Thiết kế Project quyền hẹp và AppSet nhiều env.
- [ ] Debug một render error và một runtime error.
- [ ] Viết production checklist, backup/restore và incident runbook.

Quay lại [README](../README.md).
