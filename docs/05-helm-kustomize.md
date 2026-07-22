# 05 — Manifest thuần, Kustomize và Helm

Argo CD cần biến source thành Kubernetes manifest. Ba cách phổ biến có trade-off khác nhau.

## 1. Chọn công cụ bằng câu hỏi

| Nhu cầu | Chọn |
|---|---|
| Ít resource, không cần biến thể môi trường | YAML thuần |
| Cùng base, patch nhỏ giữa dev/staging/prod | Kustomize |
| Đóng gói app tái sử dụng, có schema values/template | Helm |
| Chart ở repo vendor, values ở repo GitOps | Helm multiple sources có kiểm soát |

Đừng chọn Helm chỉ vì “production phải dùng Helm”; template quá linh hoạt có thể khó đọc và khó diff hơn Kustomize.

## 2. YAML thuần

Application:

```yaml
source:
  repoURL: https://github.com/linhdo04/argocd-learning.git
  targetRevision: main
  path: labs/base
```

Ưu điểm:

- gần với Kubernetes API;
- diff dễ hiểu;
- ít lớp render.

Nhược điểm:

- lặp cấu hình nhiều môi trường;
- thay tên/label hàng loạt khó hơn.

## 3. Kustomize mental model

Kustomize dùng base + overlays, không dùng template syntax trong YAML.

```text
labs/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/kustomization.yaml
    └── prod/kustomization.yaml
```

Render trước khi commit:

```bash
kubectl kustomize labs/overlays/dev
kubectl kustomize labs/overlays/prod
```

So sánh:

```bash
diff -u \
  <(kubectl kustomize labs/overlays/dev) \
  <(kubectl kustomize labs/overlays/prod)
```

Application nên trỏ thẳng tới overlay:

```yaml
source:
  path: labs/overlays/prod
```

### Những gì nên nằm trong overlay

- replicas/resource limits;
- hostname/Ingress;
- feature flags không nhạy cảm;
- namespace/labels;
- image tag/digest theo promotion.

### Những gì không nên commit plaintext

- database password;
- API tokens;
- private key;
- kubeconfig.

## 4. Helm trong Argo CD

Argo CD dùng Helm để **render manifest**. Argo CD không vận hành release lifecycle giống `helm upgrade` và không nên cùng Helm CLI quản lý một release.

### Chart nằm trong Git

```yaml
source:
  repoURL: https://github.com/example/platform-config.git
  targetRevision: main
  path: charts/my-app
  helm:
    releaseName: my-app
    valueFiles:
      - values-prod.yaml
```

### Chart repository

```yaml
source:
  repoURL: https://charts.example.com
  chart: my-app
  targetRevision: 1.4.2
  helm:
    valuesObject:
      replicaCount: 3
```

Với chart repository, dùng `chart`; với chart trong Git, dùng `path`. Đừng đặt cả hai.

## 5. Thứ tự override Helm

Khi nhiều cơ chế cùng đặt một key, cơ chế có ưu tiên cao hơn thắng. Để tài liệu dễ audit:

- giữ giá trị mặc định trong chart;
- giữ khác biệt môi trường trong file values;
- tránh hàng chục `parameters` rải trong Application;
- dùng `valuesObject` cho cấu hình nhỏ và rõ;
- render thử đúng version Helm/Kustomize mà Argo CD dùng.

Kiểm tra local:

```bash
helm template my-app ./charts/my-app -f ./charts/my-app/values-prod.yaml
```

## 6. Multiple sources

Use case hợp lý: chart vendor và values nội bộ tách repo.

```yaml
sources:
  - repoURL: https://charts.example.com
    chart: my-app
    targetRevision: 1.4.2
    helm:
      valueFiles:
        - $values/environments/prod/my-app.yaml
  - repoURL: https://github.com/example/gitops-values.git
    targetRevision: main
    ref: values
```

Không dùng multiple sources để gom nhiều ứng dụng không liên quan vào một Application. ApplicationSet hoặc App of Apps diễn đạt ownership tốt hơn.

Nếu hai source render cùng `group/kind/namespace/name`, một source có thể ghi đè source khác và Argo CD cảnh báo repeated resource. Hãy coi đó là dấu hiệu thiết kế cần xem lại, không phải kỹ thuật overlay chính.

## 7. Pin version và tính tái tạo

| Môi trường | Chiến lược phổ biến |
|---|---|
| Dev | Theo branch để phản hồi nhanh |
| Staging | Tag/commit đã qua dev |
| Production | Commit SHA, tag bất biến, chart version cụ thể; image digest nếu cần supply-chain chặt |

`latest`, `HEAD` và range mơ hồ làm khó trả lời “production đang chạy chính xác artifact nào?”.

## 8. Debug render

Trong UI, mở **MANIFEST** để xem kết quả Argo CD thực sự chuẩn bị apply.

CLI:

```bash
argocd app manifests APP_NAME
argocd app diff APP_NAME
```

Nếu local render được nhưng Argo CD không render được, kiểm tra:

- version tool;
- đường dẫn tương đối;
- file values bị thiếu;
- repo credential;
- plugin/env chỉ tồn tại ở máy local;
- dependency chart chưa fetch được.

## Bài tập

1. Render `dev` và `prod` overlays.
2. Chỉ ra chính xác khác biệt replica, label và resource limit.
3. Tạo một Application trỏ `labs/overlays/dev`.
4. Trong UI, so sánh source file với tab **MANIFEST**.

Tiếp theo: [06 — AppProject và ApplicationSet](06-appproject-applicationset.md).
