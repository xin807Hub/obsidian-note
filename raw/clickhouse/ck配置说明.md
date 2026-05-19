SETTINGS
/* 建议：跑大批量时提升并行度/外溢阈值（按你机器调） */
```SQL
max_threads = 0,                               -- 0=自动；或设为 CPU 核数
max_memory_usage = 0,                          -- 0=自动；或给一个安全上限
max_bytes_before_external_group_by = 4e9,      -- 允许 group by 外溢（按需）
allow_experimental_analyzer = 1;               -- 25.3 建议开启

```

逐条解释一下这几个 ClickHouse 的 SETTINGS 配置在 25.3.3.42 里的作用和调优思路：

---

**1.**

```sql
max_threads = 0
```

* **作用**：限制单个查询的最大执行线程数（并行度）。
* **值解释**：

  * `0` = 自动（ClickHouse 会按 `max_threads` 默认值来设置，一般等于 `cpu_cores * 1.0` 左右）。
  * 可以手动指定，比如 `max_threads=16` 强制用 16 线程跑。
* **调优思路**：

  * **大数据量批处理** → 可设置为 CPU 核数（例如 32 核设 32），以榨干性能。
  * **小查询并发多** → 适当限制（比如 8），避免同时很多查询互相抢 CPU。

---

**2.**

```sql
max_memory_usage = 0
```

* **作用**：限制单个查询可用的最大内存。
* **值解释**：

  * `0` = 不限制（按系统默认或 `users.xml` 配置来）。
  * 可以指定，比如 `max_memory_usage=20G` 限制查询最多用 20G 内存，超了直接抛错。
* **调优思路**：

  * 大数据分析 → 建议给个合理上限，防止某个查询吃爆全机内存。
  * 如果查询经常 out-of-memory → 要么加内存，要么让它外溢（结合下面 `max_bytes_before_external_group_by`）。

---

**3.**

```sql
max_bytes_before_external_group_by = 4e9
```

* **作用**：当 `GROUP BY` 的中间数据在内存中超过这个字节数（这里是 4GB）时，允许将数据临时写到磁盘（外溢）。
* **好处**：

  * 防止因为超大 `GROUP BY` 把内存打满。
  * 在外溢后，ClickHouse 会分批处理，最后合并结果。
* **坏处**：

  * 会用到磁盘 IO，速度比全内存慢。
* **调优思路**：

  * 如果你内存够大 → 设大一点甚至禁用（=0）。
  * 如果内存容易 OOM → 设小一点（比如 1\~4G），让它早点外溢。

---

**4.**

```sql
allow_experimental_analyzer = 1
```

* **作用**：开启 ClickHouse 新一代的“查询分析器”解析模式（实验性）。
* **25.3 版本变化**：

  * 新 analyzer 支持更多复杂 SQL（CTE 嵌套、复杂 join/subquery、语法容错更好）。
  * 一些旧 SQL 在新 analyzer 下执行计划更优。
* **建议**：

  * 在 25.x 新版本已经比较稳定，可以长期开启。
  * 如果发现个别 SQL 在 analyzer 下报错，可以临时关掉（设为 0）。

---

💡 **总结调优建议（你机器 32 核 128G 内存假设）**

```sql
SETTINGS
    max_threads = 32,                      -- 用满 CPU
    max_memory_usage = 64G,                 -- 单查询最多用一半内存
    max_bytes_before_external_group_by = 8e9, -- 超 8GB group by 中间数据就外溢
    allow_experimental_analyzer = 1;
```

这样大批量跑的时候既能并行又能防 OOM，小查询又不会受限。

---
