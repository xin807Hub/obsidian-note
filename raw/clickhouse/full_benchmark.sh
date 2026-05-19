#!/bin/bash

# ClickHouse 排序键优化 - 完整性能测试报告
# 服务器: 192.168.6.211:8123
# 数据库: TK_DB_SP

CH_HOST="192.168.6.211"
CH_PORT="8123"
CH_USER="default"
CH_PASS='Ck@2o20...'
CH_DB="TK_DB_SP"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 构建基础 URL
BASE_URL="http://${CH_HOST}:${CH_PORT}/"

# 结果存储
REPORT_FILE="benchmark_report_$(date +%Y%m%d_%H%M%S).md"

# 执行查询函数
run_query() {
    local query="$1"
    curl -s --user "${CH_USER}:${CH_PASS}" "${BASE_URL}" --data-binary "$query"
}

# 执行查询并返回耗时
run_query_with_time() {
    local query="$1"
    local start_time end_time
    start_time=$(date +%s%3N)
    local result
    result=$(curl -s --user "${CH_USER}:${CH_PASS}" "${BASE_URL}" --data-binary "$query")
    end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    echo "$result"
    return $duration
}

# 清除缓存
drop_cache() {
    run_query "SYSTEM DROP MARK CACHE" > /dev/null 2>&1
    run_query "SYSTEM DROP UNCOMPRESSED CACHE" > /dev/null 2>&1
}

# 开始报告
echo "# ClickHouse 排序键优化 - 性能测试报告" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}  ClickHouse 排序键优化 - 性能测试${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo "连接: ${CH_HOST}:${CH_PORT}/${CH_DB}"
echo ""

echo "## 测试环境" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- 数据库服务器: ${CH_HOST}:${CH_PORT}" >> "$REPORT_FILE"
echo "- 数据库: ${CH_DB}" >> "$REPORT_FILE"
echo "- 测试时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 测试连接
echo "[1] 测试数据库连接..."
CONN_TEST=$(run_query "SELECT 1")
if [ "$CONN_TEST" = "1" ]; then
    echo -e "${GREEN}✓ 连接成功${NC}"
else
    echo -e "${RED}✗ 连接失败${NC}"
    exit 1
fi
echo ""

# 获取表信息
echo "[2] 获取表基本信息..."
echo ""

echo "### 表结构对比" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "#### ods_traffic_records_local (优化前)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
run_query "
SELECT
    engine,
    partition_key,
    primary_key,
    sorting_key
FROM system.tables
WHERE database = '${CH_DB}' AND name = 'ods_traffic_records_local'
FORMAT PrettyCompact
" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "#### ods_traffic_records_local_new (优化后)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
run_query "
SELECT
    engine,
    partition_key,
    primary_key,
    sorting_key
FROM system.tables
WHERE database = '${CH_DB}' AND name = 'ods_traffic_records_local_new'
FORMAT PrettyCompact
" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -e "${YELLOW}--- ods_traffic_records_local (优化前) ---${NC}"
run_query "
SELECT
    engine,
    partition_key,
    primary_key,
    sorting_key
FROM system.tables
WHERE database = '${CH_DB}' AND name = 'ods_traffic_records_local'
FORMAT PrettyCompact
"

echo ""
echo -e "${YELLOW}--- ods_traffic_records_local_new (优化后) ---${NC}"
run_query "
SELECT
    engine,
    partition_key,
    primary_key,
    sorting_key
FROM system.tables
WHERE database = '${CH_DB}' AND name = 'ods_traffic_records_local_new'
FORMAT PrettyCompact
"
echo ""

# 获取表大小
echo "[3] 表数据统计..."
echo ""

echo "### 表数据统计" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
run_query "
SELECT
    table,
    formatReadableSize(sum(bytes)) as size,
    formatReadableQuantity(sum(rows)) as rows,
    count() as parts
FROM system.parts
WHERE database = '${CH_DB}'
  AND table IN ('ods_traffic_records_local', 'ods_traffic_records_local_new')
  AND active
GROUP BY table
FORMAT PrettyCompact
" >> "$REPORT_FILE"
echo "```" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

run_query "
SELECT
    table,
    formatReadableSize(sum(bytes)) as size,
    formatReadableQuantity(sum(rows)) as rows,
    count() as parts
FROM system.parts
WHERE database = '${CH_DB}'
  AND table IN ('ods_traffic_records_local', 'ods_traffic_records_local_new')
  AND active
GROUP BY table
FORMAT PrettyCompact
"
echo ""

# 获取样本 msisdn
echo "[4] 采集样本数据..."
SAMPLE_MSISDN=$(run_query "SELECT msisdn FROM ${CH_DB}.ods_traffic_records_local WHERE msisdn != '' LIMIT 1 FORMAT TSVRaw")
if [ -z "$SAMPLE_MSISDN" ]; then
    SAMPLE_MSISDN="8619936427398"
fi
echo "样本 MSISDN: ${SAMPLE_MSISDN}"
echo ""

# 获取时间范围
echo "[5] 数据时间范围..."
run_query "
SELECT
    min(start_time) as min_time,
    max(start_time) as max_time
FROM ${CH_DB}.ods_traffic_records_local
FORMAT PrettyCompact
"
echo ""

echo "==============================================="
echo "开始性能测试"
echo "==============================================="
echo ""

echo "## 性能测试结果" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# ==================== 场景 S1 ====================
echo -e "${BLUE}[场景 S1] 基准查询 - 原截图场景复现${NC}"
echo "SELECT count(*) FROM table WHERE start_time >= '2026-03-20' AND start_time < '2026-03-31' AND msisdn = '${SAMPLE_MSISDN}'"
echo ""

echo "### 场景 S1: 基准查询" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "查询语句: \`SELECT count(*) FROM table WHERE start_time >= '2026-03-20' AND start_time < '2026-03-31' AND msisdn = '${SAMPLE_MSISDN}'\`" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

run_s1() {
    local table=$1
    echo -e "${CYAN}--- 测试表: ${table} ---${NC}"

    drop_cache
    sleep 0.5

    # 记录查询开始时间
    local start_time end_time client_duration
    start_time=$(date +%s%3N)

    local query_result
    query_result=$(run_query "SELECT count(*) FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 00:00:00' AND start_time < '2026-03-31 00:00:00' AND msisdn = '${SAMPLE_MSISDN}' FORMAT TSVRaw")

    end_time=$(date +%s%3N)
    client_duration=$((end_time - start_time))

    # 获取查询日志统计
    sleep 0.5
    local stats
    stats=$(run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes,
    result_rows,
    formatReadableSize(memory_usage) as memory
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%SELECT count(*)%${table}%${SAMPLE_MSISDN}%'
ORDER BY event_time DESC
LIMIT 1
FORMAT TSVRaw
")

    echo "查询结果: count = $query_result"
    echo "客户端耗时: ${client_duration} ms"
    echo "服务端统计:"
    echo "$stats" | tr '\t' '|' | sed 's/|/ | /g' | sed 's/^/  /'
    echo ""

    # 记录到报告
    echo "#### ${table}" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- 查询结果: $query_result 条" >> "$REPORT_FILE"
    echo "- 客户端耗时: ${client_duration} ms" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "| 指标 | 数值 |" >> "$REPORT_FILE"
    echo "|------|------|" >> "$REPORT_FILE"
    local duration_val=$(echo "$stats" | cut -f1)
    local read_rows=$(echo "$stats" | cut -f2)
    local read_bytes=$(echo "$stats" | cut -f3)
    local result_rows=$(echo "$stats" | cut -f4)
    local memory=$(echo "$stats" | cut -f5)
    echo "| 服务端耗时 | ${duration_val} ms |" >> "$REPORT_FILE"
    echo "| 读取行数 | ${read_rows} |" >> "$REPORT_FILE"
    echo "| 读取字节 | ${read_bytes} |" >> "$REPORT_FILE"
    echo "| 结果行数 | ${result_rows} |" >> "$REPORT_FILE"
    echo "| 内存使用 | ${memory} |" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    # 返回关键指标用于对比
    echo "${duration_val}|${read_rows}|${read_bytes}|${client_duration}|${query_result}"
}

echo "#### ods_traffic_records_local (优化前)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
OLD_S1=$(run_s1 "ods_traffic_records_local")

echo "#### ods_traffic_records_local_new (优化后)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
NEW_S1=$(run_s1 "ods_traffic_records_local_new")

# ==================== 场景 S2 ====================
echo -e "${BLUE}[场景 S2] 聚合查询 - 按 app_type 分组统计${NC}"
echo ""

echo "### 场景 S2: 聚合查询" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

run_s2() {
    local table=$1
    echo -e "${CYAN}--- 测试表: ${table} ---${NC}"

    drop_cache
    sleep 0.5

    local start_time end_time client_duration
    start_time=$(date +%s%3N)

    local query_result
    query_result=$(run_query "SELECT app_type, count(*) as cnt, sum(up_byte) as up, sum(dn_byte) as dn FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 00:00:00' AND start_time < '2026-03-31 00:00:00' AND msisdn = '${SAMPLE_MSISDN}' GROUP BY app_type ORDER BY cnt DESC LIMIT 5 FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    client_duration=$((end_time - start_time))

    echo "$query_result"
    echo ""
    echo "客户端耗时: ${client_duration} ms"

    sleep 0.5
    local stats
    stats=$(run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes,
    formatReadableSize(memory_usage) as memory
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%SELECT app_type%${table}%${SAMPLE_MSISDN}%'
ORDER BY event_time DESC
LIMIT 1
FORMAT TSVRaw
")
    echo "服务端统计: $stats"
    echo ""

    echo "#### ${table}" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "$query_result" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- 客户端耗时: ${client_duration} ms" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

run_s2 "ods_traffic_records_local"
run_s2 "ods_traffic_records_local_new"

# ==================== 场景 S3 ====================
echo -e "${BLUE}[场景 S3] 小时粒度查询 - toStartOfHour${NC}"
echo ""

echo "### 场景 S3: 小时粒度查询" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

run_s3() {
    local table=$1
    echo -e "${CYAN}--- 测试表: ${table} ---${NC}"

    drop_cache
    sleep 0.5

    local start_time end_time client_duration
    start_time=$(date +%s%3N)

    local query_result
    query_result=$(run_query "SELECT toStartOfHour(start_time) as hour, count(*), sum(up_byte) FROM ${CH_DB}.${table} WHERE toStartOfHour(start_time) = '2026-03-20 10:00:00' AND msisdn = '${SAMPLE_MSISDN}' GROUP BY hour FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    client_duration=$((end_time - start_time))

    echo "$query_result"
    echo ""
    echo "客户端耗时: ${client_duration} ms"

    sleep 0.5
    local stats
    stats=$(run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%toStartOfHour%${table}%${SAMPLE_MSISDN}%'
ORDER BY event_time DESC
LIMIT 1
FORMAT TSVRaw
")
    echo "服务端统计: $stats"
    echo ""

    echo "#### ${table}" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "$query_result" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- 客户端耗时: ${client_duration} ms" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

run_s3 "ods_traffic_records_local"
run_s3 "ods_traffic_records_local_new"

# ==================== 场景 S4 ====================
echo -e "${BLUE}[场景 S4] 窄时间范围查询 - 1分钟${NC}"
echo ""

echo "### 场景 S4: 窄时间范围查询 (1分钟)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

run_s4() {
    local table=$1
    echo -e "${CYAN}--- 测试表: ${table} ---${NC}"

    drop_cache
    sleep 0.5

    local start_time end_time client_duration
    start_time=$(date +%s%3N)

    local query_result
    query_result=$(run_query "SELECT count(*), sum(up_byte), sum(dn_byte) FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 10:00:00' AND start_time < '2026-03-20 10:01:00' AND msisdn = '${SAMPLE_MSISDN}' FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    client_duration=$((end_time - start_time))

    echo "$query_result"
    echo ""
    echo "客户端耗时: ${client_duration} ms"

    sleep 0.5
    local stats
    stats=$(run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%10:00:00%10:01:00%${table}%'
ORDER BY event_time DESC
LIMIT 1
FORMAT TSVRaw
")
    echo "服务端统计: $stats"
    echo ""

    echo "#### ${table}" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "$query_result" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- 客户端耗时: ${client_duration} ms" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

run_s4 "ods_traffic_records_local"
run_s4 "ods_traffic_records_local_new"

# ==================== 场景 S5 ====================
echo -e "${BLUE}[场景 S5] 大范围统计 - 30天全表聚合${NC}"
echo ""

echo "### 场景 S5: 大范围统计 (30天)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

run_s5() {
    local table=$1
    echo -e "${CYAN}--- 测试表: ${table} ---${NC}"

    drop_cache
    sleep 0.5

    local start_time end_time client_duration
    start_time=$(date +%s%3N)

    local query_result
    query_result=$(run_query "SELECT count(*), formatReadableSize(sum(up_byte)) as up, formatReadableSize(sum(dn_byte)) as dn FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-01 00:00:00' AND start_time < '2026-04-01 00:00:00' FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    client_duration=$((end_time - start_time))

    echo "$query_result"
    echo ""
    echo "客户端耗时: ${client_duration} ms"

    sleep 0.5
    local stats
    stats=$(run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes,
    formatReadableSize(memory_usage) as memory
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%SELECT count(*)%${table}%2026-03-01%'
ORDER BY event_time DESC
LIMIT 1
FORMAT TSVRaw
")
    echo "服务端统计: $stats"
    echo ""

    echo "#### ${table}" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "$query_result" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- 客户端耗时: ${client_duration} ms" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

run_s5 "ods_traffic_records_local"
run_s5 "ods_traffic_records_local_new"

# ==================== 总结 ====================
echo "==============================================="
echo "性能测试完成"
echo "==============================================="
echo ""

echo "### 测试总结" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "本次测试对比了优化前后的两张表：" >> "$REPORT_FILE"
echo "- ods_traffic_records_local: 原排序键，使用高精度时间戳" >> "$REPORT_FILE"
echo "- ods_traffic_records_local_new: 新排序键，使用 toStartOfHour 粗化时间" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**关键发现：**" >> "$REPORT_FILE"
echo "1. 两表数据量存在差异（原表约 98M 行，新表约 540M 行）" >> "$REPORT_FILE"
echo "2. 排序键从 \`start_time\` 改为 \`toStartOfHour(start_time)\`" >> "$REPORT_FILE"
echo "3. 新表将 log_time 也改为 \`toStartOfHour(log_time)\`" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**测试场景覆盖：**" >> "$REPORT_FILE"
echo "- S1: 基准查询（原截图场景）" >> "$REPORT_FILE"
echo "- S2: 聚合查询（GROUP BY）" >> "$REPORT_FILE"
echo "- S3: 小时粒度查询（利用新排序键）" >> "$REPORT_FILE"
echo "- S4: 窄时间范围查询（1分钟）" >> "$REPORT_FILE"
echo "- S5: 大范围统计（30天全表）" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -e "${GREEN}报告已保存到: ${REPORT_FILE}${NC}"
