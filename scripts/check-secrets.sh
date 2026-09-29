#!/usr/bin/env bash
# 敏感信息扫描：用于提交前拦截，也可手动扫描整个仓库
#
#   scripts/check-secrets.sh            # 扫描所有受版本控制的文件
#   scripts/check-secrets.sh --staged   # 只扫描暂存区新增行（pre-commit 用）
#
# 命中阻断级规则会以非 0 退出，从而阻止提交。
set -uo pipefail

MODE="${1:-all}"
ROOT="$(git rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/patterns" <<'PATTERNS'
\b1[3-9][0-9]{9}\b
gh[pousr]_[A-Za-z0-9]{20,}
sk-[A-Za-z0-9]{20,}
-----BEGIN [A-Z ]*PRIVATE KEY-----
eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}
AKIA[0-9A-Z]{16}
(salt|secret|passwd|password|apikey|api_key|access_key)[[:space:]]*[:=][[:space:]]*["'][^"']{8,}["']
PATTERNS

# 十六进制串规则：测试目录里会有期望摘要，故不对 test/ 生效
cat > "$TMP/patterns-hex" <<'PATTERNS'
\b[0-9a-f]{32}\b
PATTERNS

ALLOW='13800000000|test-account-id|test-device-id|test-endpoint-id|test-wallet-id|REDACTED|PLACEHOLDER|YOUR_|your_|example\.com|<[^>]*>|changeit|your_sign|sha256|integrity|sha1-|TEST_SALT'

if [ "$MODE" = "--staged" ]; then
  git diff --cached -U0 -- . ':(exclude)*.example.*' ':(exclude)*.template.*' \
    ':(exclude)**/pubspec.lock' ':(exclude)**/*.lock' ':(exclude)LICENSES/**' \
    | grep -E '^\+' | grep -v '^+++' | sed 's/^+//' > "$TMP/staged"
  grep -E -f "$TMP/patterns" "$TMP/staged" > "$TMP/input" || true
  grep -E -f "$TMP/patterns-hex" "$TMP/staged" >> "$TMP/input" || true
  LABEL="暂存区"
else
  cd "$ROOT" || exit 1
  git ls-files -z -- . ':(exclude)*.example.*' ':(exclude)*.template.*' \
    ':(exclude)**/pubspec.lock' ':(exclude)**/*.lock' ':(exclude)LICENSES/**' \
    | xargs -0 grep -IHnE -f "$TMP/patterns" 2>/dev/null > "$TMP/input" || true
  git ls-files -z -- . ':(exclude)**/test/**' ':(exclude)*.example.*' ':(exclude)*.template.*' \
    | xargs -0 grep -IHnE -f "$TMP/patterns-hex" 2>/dev/null >> "$TMP/input" || true
  LABEL="工作区"
fi

HITS=$(grep -vE "$ALLOW" "$TMP/input" 2>/dev/null || true)

if [ -n "$HITS" ]; then
  echo "✗ 检测到疑似敏感信息（$LABEL）：" >&2
  echo "$HITS" | head -30 | cut -c1-180 >&2
  COUNT=$(echo "$HITS" | wc -l)
  [ "$COUNT" -gt 30 ] && echo "  …（共 $COUNT 处）" >&2
  cat >&2 <<'EOF'

提交被拦截。处理办法：
  1) 需要提交的内容 → 改用占位值（13800000000 / test-device-id / REDACTED_XXX）
  2) 本地密钥 → 放进被 .gitignore 排除的文件（参考 score_secrets.example.dart、key.properties）
  3) 确认误报 → 在 scripts/check-secrets.sh 的 ALLOW 白名单补充规则
EOF
  exit 1
fi

echo "✓ 敏感信息扫描通过（$LABEL）"
exit 0
