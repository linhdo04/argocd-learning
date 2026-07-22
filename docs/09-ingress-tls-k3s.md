# 09 — Expose Argo CD bằng Ingress/TLS trên K3s

K3s mặc định thường cài Traefik. Trước khi viết YAML, cần tách ba lớp port.

## 1. Ba lớp port

```text
Client -> External IP:443 -> Traefik entryPoint websecure -> Service:80 -> argocd-server
```

| Lớp | Ví dụ | Ý nghĩa |
|---|---|---|
| Client/external | `443` | Port người dùng truy cập |
| Ingress entryPoint | `websecure` | Listener của Traefik |
| Backend Service | `80` hoặc `443` | Port nội bộ của `argocd-server` |

Bạn có nhiều service không có nghĩa mỗi service cần `EXTERNAL_IP:8080`, `:8081`… Ingress phân tuyến theo hostname/path trên cùng port 80/443:

```text
argocd.example.com -> argocd-server
api.example.com    -> backend-service
app.example.com    -> frontend-service
```

## 2. Hai chiến lược TLS

### A. TLS kết thúc ở Traefik

```text
Browser --HTTPS--> Traefik --HTTP/h2c--> argocd-server
```

- certificate ở Traefik/cert-manager;
- đặt `server.insecure: "true"` để Argo CD backend phục vụ HTTP;
- Traefik route UI và gRPC theo header.

Đây là mẫu trong `labs/ingress/traefik-argocd.yaml` và phù hợp để học với K3s Traefik v3.

### B. TLS passthrough

```text
Browser --TLS xuyên qua Traefik--> argocd-server
```

- Traefik không giải mã HTTP;
- certificate được Argo CD server dùng;
- route theo SNI/TCP;
- cấu hình/quan sát khác L7 termination.

Chọn một nơi terminate TLS. Lỗi redirect loop/502 thường xuất hiện khi các lớp không thống nhất HTTP/HTTPS.

## 3. Kiểm tra Traefik

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl get crd | grep -E 'ingressroutes.traefik.io|middlewares.traefik.io'
kubectl get svc -n kube-system traefik
```

Nếu K3s đã cài Traefik, không cài thêm ingress-nginx chỉ để chép một ví dụ NGINX.

## 4. DNS và External IP

```bash
kubectl get svc -n kube-system traefik
```

Trỏ record DNS:

```text
argocd.example.com -> EXTERNAL_IP
```

Trên VM GCP, còn phải kiểm tra:

- VM có external IP hay Load Balancer;
- firewall cho TCP 80/443;
- DNS trỏ đúng;
- health check/network route;
- không mở port Argo CD Pod trực tiếp ra Internet.

## 5. TLS termination ở Traefik

### Bước 1: cho backend chạy HTTP

```bash
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'

kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

`insecure` ở đây nghĩa TLS nội bộ của argocd-server bị tắt; kết nối public vẫn phải là HTTPS và TLS kết thúc tại Traefik.

### Bước 2: certificate

Nếu đã có certificate/key:

```bash
kubectl create secret tls argocd-ingress-tls \
  --namespace argocd \
  --cert=argocd.crt \
  --key=argocd.key
```

Lỗi `Cannot read file argocd.crt` nghĩa file không tồn tại ở thư mục shell hiện tại. `kubectl` không tự tạo certificate. Kiểm tra:

```bash
pwd
ls -l argocd.crt argocd.key
```

Trong production, ưu tiên cert-manager/ACME hoặc certificate do tổ chức quản lý.

### Bước 3: sửa hostname và apply

```bash
sed -n '1,220p' labs/ingress/traefik-argocd.yaml
kubectl apply -f labs/ingress/traefik-argocd.yaml
kubectl get ingressroute -n argocd
kubectl describe ingressroute argocd-server -n argocd
```

Sửa `argocd.example.com` trước khi apply.

## 6. Login CLI sau Ingress

Traefik route gRPC bằng h2c. Thử:

```bash
argocd login argocd.example.com
```

Nếu proxy/network không hỗ trợ gRPC end-to-end, dùng:

```bash
argocd login argocd.example.com --grpc-web
```

UI hoạt động không đảm bảo CLI gRPC hoạt động; chúng có protocol behavior khác nhau.

## 7. Vì sao không dùng path `/argocd` ngay?

Host riêng đơn giản hơn:

```text
https://argocd.example.com/
```

Nếu dùng `https://example.com/argocd`, phải đồng bộ `server.rootpath`, `server.basehref`, rewrite proxy và CLI `--grpc-web-root-path`. Chỉ dùng subpath khi hạ tầng thực sự yêu cầu.

## 8. Troubleshooting theo lớp

### DNS

```bash
dig +short argocd.example.com
```

### Port/firewall

```bash
curl -vk https://argocd.example.com/
```

### Traefik

```bash
kubectl logs -n kube-system deploy/traefik --since=10m
kubectl get ingressroute -A
```

### Service/endpoints

```bash
kubectl get svc,endpoints -n argocd argocd-server
```

### Argo CD server

```bash
kubectl logs -n argocd deploy/argocd-server --since=10m
```

Đọc luồng từ ngoài vào trong. Không thay ngẫu nhiên certificate, Service port và `server.insecure` cùng lúc.

## 9. Lưu ý bảo mật

- Ưu tiên UI private/VPN/IAP nếu không cần public.
- Public UI phải có TLS hợp lệ, SSO/MFA, rate limiting phù hợp.
- Tắt account admin sau bootstrap SSO.
- Không public Redis/repo-server/controller.
- Hạn chế source IP nếu có thể.
- Theo dõi login/audit và cập nhật bản vá.

Tham khảo: [Argo CD Ingress Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/).

Tiếp theo: [10 — Production và security](10-production-security.md).
