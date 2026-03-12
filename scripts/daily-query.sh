#!/bin/bash
# NotebookLM 每日主动查询脚本
# 每天早上主动查询相关信息

set -e

WORKSPACE="$HOME/.openclaw/workspace"
NLM_SCRIPT="$HOME/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh"
REPORT_FILE="$WORKSPACE/memory/notebooklm-daily-$(date +%Y%m%d).md"

echo "🔍 NotebookLM 每日主动查询"
echo ""

# Step 1: 查询昨天的工作总结
echo "Step 1: 查询昨天的工作总结..."
YESTERDAY_SUMMARY=$(bash "$NLM_SCRIPT" query \
  --agent main \
  --notebook memory-archive \
  --query "昨天（$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)）的工作中有哪些未完成的任务和需要注意的事项？" \
  2>/dev/null || echo "查询失败")

# Step 2: 查询待办任务背景
echo "Step 2: 查询待办任务背景..."
TODO_CONTEXT=$(bash "$NLM_SCRIPT" query \
  --agent main \
  --notebook memory-archive \
  --query "当前待办任务的相关背景和历史经验" \
  2>/dev/null || echo "查询失败")

# Step 3: 查询可能的风险提示
echo "Step 3: 查询可能的风险提示..."
RISK_ALERTS=$(bash "$NLM_SCRIPT" query \
  --agent main \
  --notebook troubleshooting \
  --query "最近一周的常见问题和需要注意的风险点" \
  2>/dev/null || echo "查询失败")

# Step 4: 生成报告
cat > "$REPORT_FILE" <<EOF
# NotebookLM 每日查询报告

**查询时间**: $(date '+%Y-%m-%d %H:%M:%S')

---

## 📋 昨天的工作总结

$YESTERDAY_SUMMARY

---

## 📌 待办任务背景

$TODO_CONTEXT

---

## ⚠️ 风险提示

$RISK_ALERTS

---

**报告路径**: $REPORT_FILE
EOF

echo "✅ 报告已生成：$REPORT_FILE"
echo ""

echo "📊 每日查询完成！"
