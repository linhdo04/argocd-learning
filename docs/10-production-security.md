# 10 — Đưa Argo CD vào production an toàn

Production không chỉ là thay `install.yaml` bằng `ha/install.yaml`.

## 1. Chọn vị trí quản lý

Một pattern phổ biến:

```text
Management cluster
└── Argo CD
    ├── deploy -> dev cluster
    ├── deploy -> staging cluster
    └── deploy -> prod cluster
```

Cần quyết định:

- failure của management cluster ảnh hưởng deploy nhưng workload đang chạy ra sao;
- network path đến Git và cluster đích;
- blast radius credential;
- RTO/RPO khi mất cluster quản lý.

## 2. HA

HA manifest:

```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.2/manifests/ha/install.yaml
```

Không áp thẳng lên production chỉ vì có chữ HA. Kiểm tra:

- số node và anti-affinity;
- requests/limits;
- PodDisruptionBudget;
- Redis HA behavior;
- storage/ephemeral disk cho repo-server;
- capacity Kubernetes API và Git provider.

HA không thay backup và disaster recovery.

## 3. Authentication và RBAC

Argo CD có built-in `admin` toàn quyền. Dùng cho bootstrap, sau đó chuyển sang SSO/local accounts có RBAC.

Checklist:

- SSO OIDC/SAML với MFA ở IdP;
- group mapping thay vì cấp từng cá nhân;
- `policy.default` tối thiểu, thường read-only hoặc role hẹp;
- tách quyền `get`, `sync`, `delete`, `override`, `exec`, logs;
- test policy trước rollout;
- tắt admin sau khi xác minh break-glass procedure.

Ví dụ:

```yaml
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:demo-deployer, applications, get, demo/*, allow
    p, role:demo-deployer, applications, sync, demo/*, allow
    g, platform-demo-team, role:demo-deployer
  scopes: '[groups]'
```

## 4. Repository credential

Ưu tiên:

1. GitHub App/token ngắn hạn nếu phù hợp;
2. deploy key read-only per repo;
3. token scope tối thiểu;
4. tách credential theo tenant.

Không:

- commit private key/token;
- dùng PAT cá nhân quyền rộng cho hạ tầng lâu dài;
- bỏ TLS/SSH host verification để chữa lỗi nhanh;
- cho mọi project dùng mọi credential.

## 5. Secret management

Base64 không phải mã hóa.

| Giải pháp | Mô hình |
|---|---|
| External Secrets Operator | Đồng bộ từ Secret Manager/Vault vào K8s Secret |
| Sealed Secrets | Commit ciphertext, controller giải mã trong cluster |
| SOPS + KMS/age | File mã hóa trong Git, cần integration render |
| Secrets Store CSI | Mount secret lúc runtime từ provider |

Đánh giá:

- ai có quyền giải mã;
- secret có xuất hiện trong rendered manifest/UI/log không;
- key rotation;
- backup key;
- multi-tenant isolation;
- behavior khi secret provider unavailable.

## 6. AppProject và admission policy

Defense in depth:

- AppProject giới hạn source/destination/kind;
- Kubernetes RBAC giới hạn service account;
- Pod Security/OPA/Kyverno chặn workload không đạt policy;
- NetworkPolicy giới hạn traffic;
- image policy xác minh registry/signature/provenance nếu cần.

Người được merge vào trusted GitOps repo về thực chất có khả năng ảnh hưởng cluster trong phạm vi Argo CD được cấp. Bảo vệ Git cũng là bảo vệ production.

## 7. Network

- Chỉ `argocd-server` cần giao diện người dùng/API.
- repo-server cần egress đến Git/Helm/OCI sources.
- application-controller cần Kubernetes API của cluster đích.
- Redis và internal services không public.
- UI có thể để private, chỉ public SSO callback nếu kiến trúc hỗ trợ.

## 8. Observability

Theo dõi:

- app `Degraded`, `Unknown`, sync fail liên tục;
- reconciliation/sync duration;
- repo render/request errors và Git latency;
- controller queue/Kubernetes API errors;
- Redis memory/latency;
- pod restarts, CPU, RAM, ephemeral storage;
- số app/resource/cluster theo shard.

Cảnh báo `OutOfSync` vài giây sau commit thường gây noise. Cảnh báo theo duration, môi trường và tác động.

## 9. Backup

Git lưu desired manifests nhưng không chứa toàn bộ trạng thái vận hành.

Backup được mã hóa:

- Application/AppProject/ApplicationSet nếu không hoàn toàn bootstrap từ Git;
- `argocd-cm`, `argocd-rbac-cm`, notification config;
- repository/cluster credential Secrets;
- SSO/TLS/webhook secrets;
- datastore/etcd theo chiến lược cluster.

Có thể dùng:

```bash
argocd admin export > argocd-export.yaml
```

File export có thể chứa dữ liệu nhạy cảm; không commit plaintext. Backup chỉ đáng tin sau khi restore test.

## 10. Upgrade

1. Xác định version hiện tại và target.
2. Đọc release notes + từng upgrade guide giữa minor versions.
3. Backup/export.
4. Kiểm tra deprecated config và CRD.
5. Nâng dev/staging.
6. Test login, repo, render, sync, hooks, notifications, metrics.
7. Nâng production theo change window.
8. Có rollback plan tương thích schema.

Không nhảy nhiều minor mà bỏ qua migration guide. CLI và server nên cùng minor.

## 11. Disaster recovery drill

Kịch bản kiểm thử:

1. Tạo management cluster sạch.
2. Cài đúng version Argo CD.
3. Restore config/credential an toàn.
4. Bootstrap root apps.
5. Xác minh không tạo destructive sync ngoài ý muốn.
6. Đo RTO/RPO.
7. Ghi lại bước thủ công và cải tiến automation.

## Production readiness checklist

- [ ] Ownership/on-call/runbook rõ.
- [ ] SSO/MFA/RBAC tối thiểu; admin được kiểm soát.
- [ ] UI/API exposure và TLS được threat-model.
- [ ] Project/cluster credential không rộng hơn nhu cầu.
- [ ] Secrets không plaintext trong Git.
- [ ] Branch protection/CODEOWNERS/required checks.
- [ ] Metrics, logs, alert, notification đã test.
- [ ] Backup và restore drill.
- [ ] Capacity/HA/PDB/resources đã đo.
- [ ] Upgrade và emergency stop procedure.

Tiếp theo: [11 — Troubleshooting](11-troubleshooting.md).
