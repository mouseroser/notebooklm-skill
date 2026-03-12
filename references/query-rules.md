# NotebookLM 主动查询规则

**目的**: 在日常工作中主动利用 NotebookLM 的深度知识

---

## 📋 何时查询 NotebookLM

### 场景 1: 遇到问题时
**触发条件**:
- 命令执行失败
- 配置问题
- 架构疑问
- 不确定的决策

**查询流程**:
1. 先查询 `openclaw-docs` - OpenClaw 相关问题
2. 再查询 `troubleshooting` - 历史故障排查
3. 最后查询 `memory-archive` - 历史经验

**示例**:
```bash
# OpenClaw 配置问题
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook openclaw-docs \
  --query "如何配置 Telegram 群组绑定？"

# 历史故障排查
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook troubleshooting \
  --query "Cron 任务执行失败的常见原因"
```

---

### 场景 2: 开始新任务前
**触发条件**:
- 启动流水线任务
- 创建新 skill
- 重要决策

**查询流程**:
1. 查询相关 notebook 的历史经验
2. 查询类似任务的最佳实践
3. 查询可能的风险点

**示例**:
```bash
# 启动星链流水线前
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook starchain-knowledge \
  --query "L3 级任务的关键注意事项和历史教训"

# 创建新 skill 前
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook memory-archive \
  --query "创建 skill 时的常见错误和最佳实践"
```

---

### 场景 3: 做重要决策时
**触发条件**:
- 架构调整
- 流程变更
- 新功能设计

**查询流程**:
1. 查询历史类似决策
2. 查询相关的教训和经验
3. 跨 notebook 关联分析

**示例**:
```bash
# 架构调整决策
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook memory-archive \
  --query "过去的架构调整中有哪些成功和失败的经验？"
```

---

### 场景 4: 每日工作开始时
**触发条件**:
- 每天早上第一次工作
- 查看待办任务时

**查询流程**:
1. 查询昨天的工作总结
2. 查询待办任务的相关背景
3. 查询可能的风险提示

**示例**:
```bash
# 每日工作回顾
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook memory-archive \
  --query "昨天的工作中有哪些未完成的任务和需要注意的事项？"
```

---

## 🔄 跨 Notebook 关联分析

### 何时使用
- 复杂问题需要多方面信息
- 需要综合历史经验和文档
- 需要跨领域的洞察

### 查询策略
1. **问题定位** → `troubleshooting`
2. **文档查询** → `openclaw-docs`
3. **历史经验** → `memory-archive`
4. **领域知识** → `starchain-knowledge` / `stareval-research` / `media-research`

### 示例流程
```bash
# Step 1: 查询问题
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook troubleshooting \
  --query "Cron 任务路径错误"

# Step 2: 查询文档
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook openclaw-docs \
  --query "Cron 任务配置规范"

# Step 3: 查询历史
bash ~/.openclaw/skills/notebooklm/scripts/nlm-gateway.sh query \
  --agent main \
  --notebook memory-archive \
  --query "过去如何解决 Cron 路径问题"
```

---

## 📊 查询频率目标

| 场景 | 目标频率 | 当前频率 | 差距 |
|------|---------|---------|------|
| 遇到问题时 | 100% | ~20% | ⚠️ 大 |
| 开始新任务前 | 80% | ~10% | ⚠️ 大 |
| 做重要决策时 | 100% | ~30% | ⚠️ 中 |
| 每日工作开始时 | 50% | ~5% | ⚠️ 大 |

---

## 🎯 改进目标

### 短期（本周）
- [ ] 遇到问题时 100% 查询 NotebookLM
- [ ] 开始新任务前至少查询一次
- [ ] 每天早上查询一次昨天的工作总结

### 中期（本月）
- [ ] 建立跨 notebook 查询的习惯
- [ ] 在重要决策前必查 NotebookLM
- [ ] 每周回顾 NotebookLM 的查询效果

### 长期（持续）
- [ ] NotebookLM 成为日常工作的第一参考
- [ ] 自动化更多查询场景
- [ ] 持续优化查询策略

---

**创建时间**: 2026-03-12  
**维护者**: main (小光)  
**状态**: ✅ 生效
