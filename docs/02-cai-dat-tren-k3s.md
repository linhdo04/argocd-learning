# 02 — Cài Argo CD trên K3s

Chương này dùng một K3s cluster đã hoạt động. Nếu bạn dùng kind/minikube, phần cài Argo CD giống nhau; phần Ingress được tách ở chương 09.

## 1. Điều kiện đầu vào

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl version
```

Chỉ tiếp tục khi:

- context đúng cluster lab;
- ít nhất một node `Ready`;
- bạn có quyền tạo namespace, CRD, ClusterRole và ClusterRoleBinding.

Argo CD không dùng Cloud SQL làm database riêng. Trạng thái cấu hình của Argo CD được lưu bằng Kubernetes resources trong cluster, tức cuối cùng ở datastore/etcd mà K3s sử dụng. Cloud SQL của ứng dụng là chuyện khác.

## 2. Chọn kiểu cài

| Kiểu | Dùng khi | Lưu ý |
|---|---|---|
| `install.yaml` | Lab, demo, thử nghiệm; quản lý cùng cluster | Non-HA, có quyền cluster-wide mặc định |
| `ha/install.yaml` | Production cần HA | Cần đủ node/tài nguyên và vận hành Redis HA |
| Helm chart | Muốn quản lý values/release có cấu trúc | Phải pin chart + app version và hiểu values |
| `core-install.yaml` | Headless, không cần UI/API/multi-tenancy | Không phù hợp bài học UI này |

Lab dùng `install.yaml`.

## 3. Cài đặt có pin version

```bash
export ARGOCD_VERSION=v3.4.2

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
```

Vì manifest chứa CRD lớn, server-side apply tránh giới hạn annotation của client-side apply trong một số tình huống. Pin version giúp lần cài sau tái tạo đúng nội dung; không dùng URL `stable` trong automation production.

## 4. Chờ đúng cách

```bash
kubectl wait --for=condition=Available deployment --all \
  -n argocd --timeout=300s

kubectl get deployment,statefulset,pod,service -n argocd
```

Bạn chưa cần mọi Pod `1/1` ngay lập tức. Hãy theo dõi:

```bash
kubectl get pods -n argocd -w
```

Nếu quá timeout:

```bash
kubectl get events -n argocd --sort-by=.lastTimestamp
kubectl describe pod -n argocd POD_NAME
```

Phân biệt:

- `Pending`: thường do scheduling, PVC, resource hoặc taint;
- `ImagePullBackOff`: registry/network/image;
- `CrashLoopBackOff`: container khởi động rồi lỗi; xem log;
- readiness chưa đạt: Pod chạy nhưng chưa sẵn sàng nhận traffic.

## 5. Truy cập UI bằng port-forward

Port-forward là cách an toàn và ít biến số nhất cho lần đầu:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Luồng mạng:

```text
trình duyệt https://localhost:8080
        -> kubectl tunnel
        -> Service argocd-server:443
        -> argocd-server Pod
```

`8080` chỉ là port trên máy bạn. Nó không có nghĩa Ingress phải dùng port 8080.

## 6. Đăng nhập lần đầu

Lấy mật khẩu:

```bash
argocd admin initial-password -n argocd
```

Hoặc không cần CLI:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Mở `https://localhost:8080`, dùng:

```text
username: admin
password: <giá trị vừa lấy>
```

Cảnh báo certificate là bình thường trong lab vì certificate mặc định không được trình duyệt tin cậy.

Đổi mật khẩu:

```bash
argocd login localhost:8080 --username admin --insecure
argocd account update-password
```

Sau khi đổi thành công:

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

Secret này chỉ chứa mật khẩu khởi tạo; tài liệu chính thức khuyến nghị xóa sau khi đổi.

## 7. Kiểm tra phiên bản client/server

```bash
argocd version
```

CLI và server nên cùng minor version. Patch khác nhau thường vẫn tương thích, nhưng dùng cùng bản giảm biến số khi học và troubleshooting.

## 8. Hiểu namespace `argocd`

```bash
kubectl get applications,applicationsets,appprojects -n argocd
```

Các CR `Application` thường nằm trong namespace `argocd`, nhưng workload mà chúng quản lý có thể nằm ở `demo`, `backend`, `production`…

```yaml
metadata:
  namespace: argocd       # Application object nằm ở đây
spec:
  destination:
    namespace: demo       # Workload được deploy vào đây
```

Nhầm hai namespace này là lỗi rất phổ biến.

## 9. Cài đặt thành công nghĩa là gì?

Không chỉ là “Pod Running”. Checklist:

- [ ] Các deployment của Argo CD `Available`.
- [ ] UI mở được qua port-forward.
- [ ] Đăng nhập được.
- [ ] CLI trả về server version.
- [ ] `kubectl get applications -n argocd` chạy được.
- [ ] Biết cách xem events và log nếu có lỗi.

## 10. Gỡ lab

Đọc kỹ context trước:

```bash
kubectl config current-context
```

Xóa namespace:

```bash
kubectl delete namespace argocd
```

Lệnh này xóa mọi namespaced resource trong `argocd` và chính namespace, nhưng CRD/cluster-scoped RBAC do bộ cài tạo có thể còn. Vì vậy “xóa namespace” không nhất thiết là gỡ sạch toàn bộ Argo CD khỏi cluster.

Trong lab, cách sạch nhất nếu cluster chỉ dùng để học là xóa cả cluster. Trong production, không xóa namespace trước khi hiểu finalizer, cascading deletion, backup và bootstrap plan.

Tiếp theo: [03 — Application đầu tiên bằng UI](03-application-dau-tien-bang-ui.md).
