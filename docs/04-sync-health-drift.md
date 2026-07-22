# 04 — Sync, health, drift, prune và self-heal

Đây là chương quan trọng nhất để vận hành Argo CD an toàn.

## 1. Ba khái niệm tách biệt

### Refresh

Argo CD đọc lại source/live state và tính diff. Refresh không mặc định apply workload.

- **Refresh:** dùng cache hợp lệ nếu có.
- **Hard Refresh:** làm mới mạnh hơn, bao gồm cache manifest; dùng khi nghi cache cũ, không phải nút “sửa mọi lỗi”.

### Sync

Đưa resource trong cluster về desired state đã render. Manual sync cần người/API xác nhận; auto-sync do controller khởi chạy khi điều kiện phù hợp.

### Health assessment

Sau apply, Argo CD đánh giá resource có hoạt động hay không. Deployment thường healthy khi số replica sẵn sàng đạt yêu cầu; Pod lỗi probe có thể làm app degraded.

## 2. Sync lifecycle

1. Resolve revision.
2. Clone/fetch source.
3. Render manifest.
4. Diff desired/live.
5. Chạy `PreSync` hooks.
6. Apply resource theo phase, wave, kind và name.
7. Chờ health của wave hiện tại.
8. Chạy `PostSync` hoặc `SyncFail`.
9. Ghi result và history.

Sync không đơn giản là chạy một lệnh `kubectl apply -f folder`.

## 3. Đọc bảng SYNC OPTIONS trên UI

Tên hiển thị có thể thay đổi nhẹ giữa phiên bản; ý nghĩa cốt lõi:

| Tùy chọn UI | Ý nghĩa | Khi dùng |
|---|---|---|
| `PRUNE` | Xóa resource Argo CD đang quản lý nhưng không còn trong desired state | Chỉ sau khi xem danh sách resource sẽ xóa |
| `DRY RUN` | Mô phỏng validation/apply, không persist thay đổi | Kiểm tra trước operation rủi ro |
| `APPLY ONLY` | Chỉ apply, bỏ hooks | Tình huống đặc biệt; có thể phá workflow migration |
| `FORCE` | Thường xóa/tạo lại resource khi cần | Rủi ro downtime và mất dữ liệu |
| `PRUNE LAST` | Để xóa resource sau các wave apply/health | Migration/thay resource an toàn hơn |
| `REPLACE` | Dùng replace/create thay apply | Có thể recreate resource; không bật như thuốc chữa chung |

Nguyên tắc: nếu không giải thích được resource nào sẽ bị xóa/recreate, chưa bật tùy chọn đó.

## 4. Auto-sync

File `labs/argocd/application-auto.yaml` chứa:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: true
    selfHeal: true
    allowEmpty: false
```

Ý nghĩa từng trường:

- `enabled`: cho phép controller tự sync.
- `prune`: tự xóa resource không còn trong Git.
- `selfHeal`: live drift cũng kích hoạt sync, không chỉ commit mới.
- `allowEmpty`: có chấp nhận source render ra zero resource hay không.

Áp dụng:

```bash
kubectl apply -f labs/argocd/application-auto.yaml
argocd app wait demo-auto --sync --health --timeout 180
```

## 5. Lab drift và self-heal

Git khai báo hai replicas. Cố tình sửa live state:

```bash
kubectl scale deployment demo-web -n demo-auto --replicas=5
kubectl get deployment demo-web -n demo-auto -w
```

Dự đoán trước:

1. App chuyển `OutOfSync`.
2. Vì `selfHeal: true`, controller sync lại.
3. Replicas trở về `2`.

Nếu không thấy ngay:

```bash
argocd app get demo-auto --hard-refresh
kubectl describe application demo-auto -n argocd
```

Đừng kết luận self-heal hỏng chỉ vì nó không xảy ra trong một giây; controller làm việc theo vòng reconcile và timeout.

## 6. Lab commit mới và auto-sync

Đổi nội dung trang trong `labs/base/configmap.yaml`, commit và push. Theo dõi:

```bash
argocd app get demo-auto --refresh
argocd app history demo-auto
```

Ứng dụng sẽ sync commit mới. Nếu ConfigMap đã đổi nhưng Pod không tự reload nội dung trong một ứng dụng thực, đó là hành vi workload, không phải Argo CD. Bạn có thể dùng checksum annotation hoặc cơ chế reload phù hợp.

## 7. Lab prune an toàn

Trong branch lab:

1. Xóa `configmap.yaml` khỏi `kustomization.yaml` và Git.
2. Commit/push.
3. Xem UI liệt kê ConfigMap sắp bị prune.
4. Quan sát workload có thể lỗi vì volume vẫn tham chiếu ConfigMap.
5. `git revert` commit vừa tạo.

Bài học: prune có thể xóa đúng theo Git nhưng desired state mới vẫn sai logic. GitOps đảm bảo hội tụ, không đảm bảo commit của bạn đúng.

## 8. Vì sao `allowEmpty: false` quan trọng?

Một lỗi path, generator hoặc commit có thể làm source render thành rỗng. Kết hợp auto-prune và allow-empty có thể xóa toàn bộ app. Giữ `false` là lớp bảo vệ mặc định; chỉ bật `true` khi quy trình decommission có chủ đích.

## 9. Sync options trong YAML

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - PruneLast=true
    - FailOnSharedResource=true
    - ApplyOutOfSyncOnly=true
```

| Option | Giá trị |
|---|---|
| `CreateNamespace=true` | Tạo namespace đích nếu chưa có |
| `PruneLast=true` | Prune ở cuối operation |
| `FailOnSharedResource=true` | Fail nếu resource đã thuộc app khác |
| `ApplyOutOfSyncOnly=true` | Chỉ apply resource đang lệch; hữu ích app lớn |
| `ServerSideApply=true` | Server-side apply; cần hiểu field ownership |
| `RespectIgnoreDifferences=true` | Không apply field đã cấu hình ignore |

Không sao chép toàn bộ option vào mọi app. Mỗi option là quyết định vận hành.

## 10. Drift hợp lệ và diff noise

Drift có thể do:

- người sửa trực tiếp;
- HPA thay replicas;
- mutating admission webhook thêm field;
- operator/controller khác sở hữu field;
- Kubernetes defaulting;
- Helm template tạo giá trị không deterministic.

Ví dụ HPA sở hữu replicas:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
  syncPolicy:
    syncOptions:
      - RespectIgnoreDifferences=true
```

Chỉ ignore field cụ thể sau khi xác định owner. Ignore toàn bộ `/spec` sẽ che drift thật và có thể che thay đổi độc hại.

## 11. Rollback theo GitOps

Với auto-sync, cách bền vững là:

```bash
git revert BAD_COMMIT_SHA
git push
```

Argo CD sync commit revert. Lịch sử Git lúc này mô tả đúng desired state hiện tại.

`argocd app rollback` hữu ích trong một số workflow manual nhưng không phải chiến lược chính khi automated sync đang bật. Live edit cũng chỉ là chữa tạm; self-heal có thể ghi đè.

## 12. Khi nào tạm dừng auto-sync?

- sự cố đang bị một desired state xấu khuếch đại;
- cần điều tra mà controller liên tục ghi đè;
- Git provider/source gặp lỗi bất thường;
- maintenance có kế hoạch.

Nếu app do ApplicationSet quản lý, sửa template/policy nguồn; sửa trực tiếp child Application có thể bị controller ghi đè.

## Checklist trước khi sync production

- [ ] Đúng app, project, cluster và namespace.
- [ ] Đúng revision/commit.
- [ ] Đã xem diff đã render.
- [ ] Biết resource nào create/update/delete/recreate.
- [ ] Migration có idempotent và timeout không.
- [ ] Có metric/smoke test và đường rollback.
- [ ] Không có người/tool khác cùng quản lý resource.

Tiếp theo: [05 — Helm và Kustomize](05-helm-kustomize.md).
