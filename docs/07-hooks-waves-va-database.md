# 07 — Hooks, sync waves và database migration

Argo CD có thể sắp thứ tự resource, nhưng thứ tự không tự biến một migration nguy hiểm thành an toàn.

## 1. Phases

| Phase | Dùng cho |
|---|---|
| `PreSync` | Kiểm tra/migration trước rollout |
| `Sync` | Resource trong quá trình sync chính |
| `PostSync` | Smoke test sau khi app healthy |
| `SyncFail` | Thu thập/chuyển thông báo khi sync lỗi |
| `PostDelete` | Tác vụ sau xóa app ở phiên bản hỗ trợ |
| `Skip` | Không apply resource đó |

Annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
```

## 2. Sync waves

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

Số nhỏ chạy trước, mặc định `0`; có thể dùng số âm.

Ví dụ:

```text
wave -2: CRD/namespace nền tảng
wave -1: config và migration
wave  0: backend
wave  1: frontend
wave  2: smoke test
```

Argo CD chờ wave trước đạt health phù hợp rồi mới tiếp tục. Một Job không hoàn tất ở wave `-1` có thể chặn cả deployment — đây thường là hành vi bảo vệ mong muốn.

## 3. Lab PreSync hook

Xem `labs/hooks/pre-sync-migration.yaml`.

```bash
kubectl apply -f labs/argocd/application-with-hook.yaml
```

Trong UI:

1. mở app `demo-hook`;
2. xem Job có biểu tượng hook;
3. sync;
4. xem Job chạy trước Deployment;
5. mở logs của Job;
6. xem Job được xóa theo hook delete policy.

Job mẫu chỉ minh họa thứ tự, không sửa database thật.

## 4. Migration phải idempotent

Argo CD có thể retry. Network có thể đứt sau khi migration thực thi nhưng trước khi status được ghi. Vì vậy migration nên:

- chạy lại không gây hỏng;
- ghi version/schema migration trong DB;
- có `activeDeadlineSeconds`;
- có `backoffLimit` hữu hạn;
- dùng lock nếu nhiều actor có thể chạy;
- không chứa credential plaintext trong manifest/log.

## 5. Expand/contract cho thay đổi schema

Đừng làm một deploy đồng thời:

1. xóa column cũ;
2. deploy code chỉ dùng column mới;
3. mong mọi Pod đổi tức thì.

An toàn hơn:

### Release A — Expand

- thêm schema mới tương thích ngược;
- code cũ vẫn chạy;
- backfill nếu cần.

### Release B — Switch

- code mới đọc/ghi schema mới;
- quan sát metrics/errors;
- rollback code vẫn không phá schema.

### Release C — Contract

- sau khi xác nhận không còn consumer cũ, xóa schema cũ bằng thay đổi riêng.

Rollback ứng dụng không tự rollback dữ liệu. Một migration destructive có thể làm image cũ không chạy được dù Git đã revert.

## 6. Argo CD và Cloud SQL

Argo CD không kết nối Cloud SQL để lưu dữ liệu của chính Argo CD. Nếu backend của bạn dùng Cloud SQL:

- migration Job cần network path đến Cloud SQL;
- dùng Workload Identity/Cloud SQL Auth Proxy hoặc cơ chế xác thực phù hợp;
- credential lấy từ secret manager;
- kiểm tra firewall/private IP/DNS;
- phân quyền DB tối thiểu cho migration;
- tách lỗi Argo sync với lỗi DB permission.

Ví dụ `permission denied for schema public` là lỗi quyền PostgreSQL của account migration/app, không phải lỗi reconciliation của Argo CD.

## 7. Hook hay initContainer?

| Hook Job | initContainer |
|---|---|
| Chạy một lần theo sync operation | Chạy cho mỗi Pod |
| Có phase/wave/history riêng | Gắn lifecycle Pod |
| Phù hợp migration toàn hệ thống | Phù hợp chuẩn bị cục bộ/idempotent |

Không chạy migration toàn DB từ mọi replica initContainer trừ khi migration framework có lock chắc chắn.

## 8. PostSync smoke test

Một PostSync Job chỉ chạy sau khi resource chính healthy. Nó nên:

- gọi health endpoint thật;
- có timeout ngắn;
- kiểm tra một hành vi quan trọng;
- không biến thành test suite hàng giờ;
- phát tín hiệu rõ khi fail.

Nếu PostSync fail, workload có thể đã được deploy. Runbook phải nói rõ rollback/revert hay giữ deployment để điều tra.

## Checklist migration production

- [ ] Backup/restore đã thử.
- [ ] Migration idempotent.
- [ ] Expand/contract và compatibility rõ.
- [ ] Timeout/backoff/lock rõ.
- [ ] Credential không nằm trong Git/log.
- [ ] Metric và alert DB có sẵn.
- [ ] Biết rollback code có tương thích schema mới không.
- [ ] Có người chịu trách nhiệm quyết định khi migration fail.

Tiếp theo: [08 — Thiết kế CI/CD GitOps](08-thiet-ke-ci-cd-gitops.md).
