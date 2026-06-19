## 这是什么

一个**自研、不依赖任何 LLM** 的 PostgreSQL 巡检报告生成器：把 `pg_check.sh` 在每个节点跑一遍输出的 `.log`，扔给 `gen_pg_report.py`，**2 秒** 后拿到 700 KB 左右的 Word 文档：封面、目录、11 章、12 张嵌入图表、风险清单、整改路线图，全部按支付级生产系统巡检报告的形态产出。

适用于：

- 一主多从 PostgreSQL 集群（9.6 / 10 / 11 / 12 / 13 / 14 / 15 / 16）
- 单实例、生产环境月度 / 季度巡检
- 上线前评估、故障复盘、合规自查
- 客户交付级报告（封面带客户名、版本号、工程师署名）

不适用于：

- TimescaleDB / Citus / Greenplum 等分支（拓扑识别会失败）
- AWS RDS / Aliyun RDS 等托管服务（OS 层指标拿不到，但 PG 部分可用）

---

## 核心特性

### 1. 真专业 DBA 视角的检查规则

不是把日志翻译成图表。每个 finding 都按 **「证据 → 影响 → 行动」** 三段式输出，所有阈值经过线上场景验证：

| 检查域     | 涵盖项（部分）                                               |
| ---------- | ------------------------------------------------------------ |
| **高可用** | 主备拓扑识别、归档链路完整性、复制延迟、复制槽滞留           |
| **性能**   | TOP CPU SQL（pg_stat_statements）、idle/active 连接比、缓存命中率、BGWriter buffers_backend 占比、未使用索引（区分 UK 唯一约束 vs 性能索引） |
| **容量**   | 表 / 索引膨胀（pg_repack 友好列表）、WAL 生成速率 + 月度预估、XID 年龄（防 wraparound）、文件系统占用 |
| **配置**   | 主备 postgresql.conf md5 一致性、关键参数审计（shared_buffers / checkpoint_completion_target / effective_cache_size / autovacuum 一族） |
| **安全**   | psql 历史明文密码扫描、REPLICATION 权限过度授予（关键发现：CDC 账号 vs 非 CDC 账号分类）、SELinux / SSL / 密码加密、账号 valid_until |
| **复制**   | 流复制延迟、Debezium 等逻辑订阅槽滞后                        |

### 2. 六维度独立健康度评分 + 高风险天花板

不是「100 - 总扣分」式的粗糙打分。改用 **六维度独立评分 → 加权综合 → 高风险天花板** 三步走：

```
1. 每个 finding 按 sev 扣分：高 12 / 中 4 / 低 1 / 信息 0
2. 按 finding.domain 分摊到 6 个维度（高可用/性能/容量/配置/安全/复制），各自从 100 扣起，钳位 [0,100]
3. 综合分 = Σ(维度分 × 权重) / Σ(权重)
   维度权重：安全 ×1.5（最关键），配置 ×0.8（噪声多），其余 ×1.0
4. 高风险天花板：≥ 2 项高 → 综合分 cap 65；= 1 项 → cap 75
   （避免加权稀释 critical 发现）
```

报告 §11.4 会展示**本次评分的完整推导过程**，65 分不是黑盒，每一分都能查回来源。

### 3. 11 章报告 + 12 张嵌入图表

| 章节                     | 关键内容                                                     |
| ------------------------ | ------------------------------------------------------------ |
| 1. 执行摘要              | AI 摘要（可选）+ 关键结论 + 健康度仪表盘 + 六维度雷达 + 风险分布饼图 |
| 2. 集群拓扑与基础信息    | 拓扑图、节点资源基线、OS / 内核 / HugePages 调优审计         |
| 3. 风险清单与整改建议    | 高/中/低/信息 四级，每项「证据 → 影响 → 行动」三段式         |
| 4. 数据库配置审计        | 61 项关键参数解读 + 主备配置一致性 md5 比对                  |
| 5. 性能与连接分析        | 连接状态饼图 + DB 命中率 + TOP 5 CPU SQL + **§5.4 BGWriter 运行态** |
| 6. 容量、空间与膨胀分析  | TOP 10 表 + 膨胀分析 + **§6.3 未使用索引（UK vs 性能拆分）** + XID 年龄 |
| 7. 高可用与流复制        | 归档统计、WAL sender 滞后图、复制槽列表                      |
| 8. 安全与合规            | 账号清单、pg_hba.conf 审计、SSL / 密码加密 / unlogged 表     |
| 9. 整改路线图            | 立即 / 7 日 / 30 日 / 60 日 四档动作清单                     |
| 10. 巡检范围、方法与局限 | + **§10.1 补采 SQL**（wait events / vacuum / SSL，可立即手工跑） |
| 11. 附录                 | 数据来源、已加载插件、全部修改参数明细、**§11.4 评分模型推导** |

12 张图表全部用 matplotlib 嵌入，中文字体 `PingFang SC` / `STHeiti` 自动 fallback。

### 4. 可选 AI 执行摘要

`--ai-summary <markdown-file>` 把 LLM 生成的 300 字执行摘要嵌入报告 §1.0，给非 DBA 读者一个 30 秒视图。Portal 自动用配置的 LLM provider 生成；CLI 独立用时也能手写一份 markdown 喂进来。

不接 LLM 这部分自动跳过，报告其他部分正常出。

---

## 怎么用

### 用法 A：通过 dbaclaw 网页（推荐）

最省事：到 <https://dbaclaw.com/pg> 拖文件，2 秒拿 docx。免装 Python / Node 依赖。

```
1. 浏览器打开 https://dbaclaw.com/pg
2. 上传每个 PG 节点跑 pg_check.sh 后的 .log（一主多从全部一起拖进来）
3. 填客户名 / 系统名 / 周期等元信息（可选）
4. 点「开始巡检」→ 2 秒后下载 .docx
```

### 用法 B：独立 CLI（无网或想批量跑）

适合：要在内网封闭环境跑、要批量处理几十个集群、要自己包装到 CI。

```bash
# 安装依赖
pip install -r requirements.txt

# 跑一次
python3 gen_pg_report.py \
  --input  ./logs                          \  # 含 .log 的目录，或直接 .log 文件
  --output ./out/PG-巡检报告.docx          \
  --system "支付核心 PG 5005"              \  # 报告封面显示
  --customer "ACME 集团"                   \
  --period  "2026 年 06 月"                \
  --engineer "DBA 团队"                    \
  --json                                       # stdout 输出结构化摘要 JSON
```

完整 CLI 参考：

```
--input PATH       一个或多个 .log 文件 OR 含 .log 的目录（可重复 --input）
--output PATH      .docx 输出路径（默认: ./PG-巡检报告-<时间戳>.docx）
--assets-dir PATH  中间图表 PNG 目录（默认: <output_dir>/_assets）
--system STR       集群展示名（封面）
--customer STR     客户名
--period STR       巡检周期（默认: 当前年月）
--report-version STR  报告版本号
--engineer STR     交付工程师
--ai-summary PATH  AI 执行摘要 markdown 文件，会嵌入 §1.0
--json             stdout 写一行 JSON 摘要（供 portal / CI 消费）
```

### 用法 C：作为 portal 引擎被调用

portal 通过 `child_process.spawn` 调起 CLI，stdout 最后一行 JSON 拿走作为 job summary。详见 [`apps/portal/lib/runner.js`](../portal/lib/runner.js)。

第三方扩展也可以参照同一接口接入，详见 [`docs/adding-an-engine.md`](../../docs/adding-an-engine.md)。

---

## 采集：`pg_check.sh`

[`pg_check.sh`](pg_check.sh) 是搭配的 bash 采集脚本，v1.2 含以下采集段（v1.0 / v1.1 升级而来）：

- 80+ 项核心采集（OS / 内核 / 文件系统 / PG 配置 / 连接 / 慢 SQL / 空间 / 膨胀 / 复制 / 安全）
- **v1.1 新增**：未使用索引、BGWriter 运行态、WAL 速率
- **v1.2 新增**：**wait events** 1 分钟分布、**vacuum 进度** 和健康度、**SSL/TLS** 实际状态

### 采集要求

|          |                                                              |
| -------- | ------------------------------------------------------------ |
| 操作系统 | Linux x86_64（CentOS / RHEL / Ubuntu / Debian）              |
| 数据库   | PostgreSQL 9.6 及以上                                        |
| 依赖     | `bash` 4+、`psql` 客户端、`free` / `lsblk` / `ip` 等基础 OS 命令 |
| 账号     | PG: 建议 `postgres` 超级用户；最低 `pg_monitor` 角色         |
| 环境变量 | `PGHOME` 指向 PostgreSQL 安装目录（含 `bin/psql`）           |

### 怎么跑

```bash
# 主备每个节点各跑一次
export PGHOME=/data/pgsql14
./pg_check.sh 5432 postgres /data/pgsql/data \
  > pg_$(hostname -s)_5432_$(date +%Y%m%d).log 2>&1

# 三个位置参数：
#   $1  端口（如 5432）
#   $2  PG 用户名
#   $3  PGDATA 目录
```

输出文件名建议：`pg_<hostname>_<port>_<YYYYMMDD>.log`。脚本会自己识别 primary / standby（基于 `pg_is_in_recovery()`），引擎会通过这个识别建拓扑。

---

## 报告示例与脚本下载

|                        | 链接                                  |
| ---------------------- | ------------------------------------- |
| 采集脚本介绍页         | <https://dbaclaw.com/collector/pg>    |
| 直接下载 `pg_check.sh` | <https://dbaclaw.com/collector/pg.sh> |
| 上传采集结果           | <https://dbaclaw.com/pg>              |
| 巡检历史               | <https://dbaclaw.com/history>         |
| API 文档               | <https://dbaclaw.com/docs>            |

---

## 输出报告里你会看到什么

打开生成的 .docx：

- **封面**：客户名、系统名、版本、健康度大字 + 仪表盘图、文档版本号
- **自动目录**：Word/WPS 中按 F9 / 右键「更新域」自动填页码
- **每章 H1/H2/H3 三层结构**，正文 11pt 微软雅黑、代码块等宽字体
- **风险三段式 callout**：高风险红色边框、中风险橙、低风险蓝、信息灰
- **图表**：六维度雷达、健康度仪表、按域柱状、TOP10 大表、TOP10 膨胀、未使用索引 TOP12、连接饼图、WAL sender 滞后、BGWriter 脏页来源、拓扑图、内存/Swap 对比、风险等级饼图

平均报告体积：**700-800 KB**。

---

## 跟其他 PG 巡检工具的对比

|             | dbaclaw-pg                 | pgBadger      | pg_activity | pgAdmin       | check_postgres  |
| ----------- | -------------------------- | ------------- | ----------- | ------------- | --------------- |
| 输入        | bash 采集 `.log`           | PG 日志 / CSV | 实时连接    | 实时连接      | 实时连接        |
| 输出        | Word docx（11 章 + 12 图） | HTML 报告     | TUI         | GUI           | 命令行 + Nagios |
| 焦点        | 月度 / 季度交付级巡检      | 慢 SQL 分析   | 实时活跃度  | 日常管理      | 监控告警        |
| 中文报告    | ✓ 原生                     | ✗             | ✗           | 部分          | ✗               |
| 健康度评分  | ✓ 六维度                   | ✗             | ✗           | ✗             | 单项阈值        |
| 整改建议    | ✓ 行动级                   | ✗             | ✗           | ✗             | 提示级          |
| AI 执行摘要 | ✓（可选）                  | ✗             | ✗           | ✗             | ✗               |
| 部署形态    | docker / CLI / SaaS        | docker / CLI  | CLI         | desktop / web | CLI             |

定位：和 pgBadger 互补，pgBadger 专注于慢 SQL 日志分析，dbaclaw-pg 是**面向客户交付的「期末报告」**。

---

## 隐私 & 安全

- 采集脚本输出的 `.log` 包含主机名、IP、账号名、SCRAM 密码哈希、业务表名等敏感信息
- **公网 SaaS 模式**：匿名上传内容 24 小时后物理删除；登录用户历史长期保留
- **自托管模式**：所有数据留在你的内网，关闭 AI 摘要（`LLM_PROVIDER=none`）后完全离线
- 详细威胁模型见 [SECURITY.md](../../SECURITY.md)

---

## 开发与贡献

PG 引擎的源码在本目录下，主要文件：

- `gen_pg_report.py` — 单文件 Python，~2700 行
  - 解析（每个 `pg_check.sh` 段一个 `parse_*` 函数）
  - 分析（`analyze()` 函数包含所有 finding 规则）
  - 评分（`weighted_score()` + 六维度算法）
  - 渲染（`build_report()` + 各 `chart_*` 函数）
- `pg_check.sh` — 采集脚本
- `tests/fixtures/` — 已脱敏的样本 `.log`（3 节点演示集群）

贡献规则见根目录 [CONTRIBUTING.md](../../CONTRIBUTING.md)。提 PR 时请：

1. 跑 `python3 gen_pg_report.py --input tests/fixtures --json` 确保通过
2. 输出 docx 用 Word/WPS/LibreOffice 都能打开
3. 加新规则时在 `analyze()` 内部，跟现有规则风格一致（sev + domain + 三段式文案）

---

## 版本

| 版本 | 日期    | 主要变化                                                     |
| ---- | ------- | ------------------------------------------------------------ |
| v1.2 | 2026-06 | wait events、vacuum 进度、SSL 检查；CDC 账号分类；UK 索引拆分；六维度评分模型 |
| v1.1 | 2026-06 | 未使用索引、BGWriter 运行态、WAL 速率、SSL 检查、局限说明章节 |
| v1.0 | 2026-05 | 首版，11 章报告，10 张图表                                   |

完整变更记录见 [CHANGELOG.md](../../CHANGELOG.md)。

---

## License

MIT，同主仓库。可商用、可修改、保留版权声明即可。
