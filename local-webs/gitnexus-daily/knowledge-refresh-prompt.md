/omh-knowledge-refresh

Đây là lượt chạy TỰ ĐỘNG theo lịch (Windows Scheduled Task `aladyn_gitnexus_daily`, ngày {{DATE}}),
headless — KHÔNG có người để trả lời hay approve. Chạy Mode 1 (Refresh, không chỉ định scope) với
các ràng buộc sau:

1. Bước 0: script gọi bạn đã `git pull --ff-only` + `gitnexus analyze --skip-agents-md` cho
   `oh-api-gitnexus` rồi. Chỉ cần kiểm tra lại (`git status`, `node .gitnexus/run.cjs status`);
   nếu vẫn stale thì KHÔNG tự chạy analyze — ghi rõ vào báo cáo.
2. Chạy bước 1–8 bình thường (scope từ `_last_refresh_scan.md` + detect_changes, sweep, so khớp,
   Semantic Impact Analysis, classify, Evidence Gate, Change Plan).
3. Bước 9 (Human Approval) = DỪNG. KHÔNG apply bất kỳ mục nào, KHÔNG tạo Change Manifest, KHÔNG
   sửa file nào trong omh-knowledge-base — trừ trường hợp ở mục 4.
4. Chỉ khi KHÔNG có drift nào (scope rỗng hoặc mọi điểm đều Compatible/Duplicate): được cập nhật
   `omh-knowledge-base/changes/_last_refresh_scan.md` (ngày + HEAD mới). Có drift → KHÔNG đụng
   tracker, để lượt chạy có người duyệt sau đó xử lý đúng mốc.
5. KHÔNG commit/push gì, KHÔNG sửa repo oh-api-gitnexus (không checkout/reset/stash).
6. Output cuối cùng (stdout) là báo cáo Markdown tiếng Việt: HEAD/index status, scope đã sweep,
   danh sách drift kèm Type + file sẽ sửa + evidence (đúng format Change Plan bước 8), hoặc
   "Không có drift". Báo cáo này được lưu lại để user duyệt sau bằng `/omh-knowledge-refresh`.
