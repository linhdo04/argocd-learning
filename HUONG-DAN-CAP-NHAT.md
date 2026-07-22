# Hướng dẫn chép bộ tài liệu vào repository

Thực hiện trên máy đã cài Git. Các bước dưới đây tạo branch riêng, không ghi thẳng vào `main`.

## 1. Clone repo hiện tại

```bash
git clone https://github.com/linhdo04/argocd-learning.git
cd argocd-learning
git switch -c docs/rewrite-argocd-course
```

Nếu repo đã clone:

```bash
cd /duong-dan/toi/argocd-learning
git status
git switch -c docs/rewrite-argocd-course
```

Nếu `git status` đang có thay đổi chưa commit, hãy commit/stash hoặc xử lý chúng trước; đừng ghi đè khi chưa biết các thay đổi đó thuộc về ai.

## 2. Giải nén bộ tài liệu

Giả sử file ZIP nằm trong `~/Downloads`:

```bash
cd ~/Downloads
unzip argocd-learning-complete.zip
```

## 3. Chép vào repo

Từ thư mục repository:

```bash
cp -R ~/Downloads/argocd-learning-rewritten/. .
```

Lệnh này cập nhật các file trùng tên và thêm file mới; nó không tự xóa file ngoài bộ tài liệu.

## 4. Review trước khi commit

```bash
git status
git diff -- README.md HUONG-DAN-CAP-NHAT.md docs labs scripts
```

Đặc biệt kiểm tra URL repository trong:

```bash
grep -R "repoURL:" -n labs
```

Bộ tài liệu đang dùng:

```text
https://github.com/linhdo04/argocd-learning.git
```

## 5. Validate

```bash
bash scripts/validate.sh
```

Nếu chưa có `kubectl`, cài nó hoặc ít nhất dùng một YAML parser trước khi commit. Script không kết nối cluster trừ khi bạn chủ động đặt `LIVE_SCHEMA_CHECK=1`.

## 6. Commit và push

```bash
git add README.md HUONG-DAN-CAP-NHAT.md docs labs scripts
git commit -m "docs: rewrite Argo CD learning course"
git push -u origin docs/rewrite-argocd-course
```

Sau đó mở Pull Request từ `docs/rewrite-argocd-course` vào `main` và xem tab **Files changed**.

## 7. Sau khi merge

```bash
git switch main
git pull --ff-only
```

Argo CD Application trong lab theo dõi `main`, nên chỉ áp dụng chúng sau khi cấu trúc mới đã có trên `main`.
