#!/bin/bash

# ClickHouse 性能测试脚本 (使用 HTTP 接口)
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
NC='\033[0m'

# 构建基础 URL (不含密码，使用 --user 参数)
BASE_URL="http://${CH_HOST}:${CH_PORT}/"

echo "==============================================="
echo "ClickHouse 排序键优化 - 性能测试"
echo "==============================================="
echo "连接: ${CH_HOST}:${CH_PORT}/${CH_DB}"
echo ""

# 测试连接
echo "[1] 测试数据库连接..."
CONN_TEST=$(curl -s --user "${CH_USER}:${CH_PASS}" "${BASE_URL}?query=SELECT%201")
if [ "$CONN_TEST" = "1" ]; then
    echo -e "${GREEN}✓ 连接成功${NC}"
else
    echo -e "${RED}✗ 连接失败${NC}"
    echo "返回: $CONN_TEST"
    exit 1
fi
echo ""

# 执行查询函数
run_query() {
    local query="$1"
    curl -s --user "${CH_USER}:${CH_PASS}" "${BASE_URL}" --data-binary "$query"
}

# 获取表信息
echo "[2] 获取表基本信息..."
echo ""
echo "--- ods_traffic_records_local (优化前) ---"
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
echo "--- ods_traffic_records_local_new (优化后) ---"
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
    SAMPLE_MSISDN="381641449273"
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

# 测试结果存储
RESULTS_OLD=""
RESULTS_NEW=""

# 测试场景 1: 基准查询 (原截图场景)
echo -e "${BLUE}[场景 S1] 基准查询 - 时间范围 + msisdn 精确匹配${NC}"
echo "查询: SELECT count(*) FROM table WHERE start_time >= '2026-03-20' AND start_time < '2026-03-31' AND msisdn = '${SAMPLE_MSISDN}'"
echo ""

test_s1() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    # 清除缓存
    run_query "SYSTEM DROP MARK CACHE" > /dev/null 2>&1
    run_query "SYSTEM DROP UNCOMPRESSED CACHE" > /dev/null 2>&1

    # 使用 explain 查看执行计划
    echo "执行计划:"
    run_query "EXPLAIN SELECT count(*) FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 00:00:00' AND start_time < '2026-03-31 00:00:00' AND msisdn = '${SAMPLE_MSISDN}'"

    # 执行查询
    echo ""
    echo "查询结果:"
    local start_time end_time duration_ms
    start_time=$(date +%s%3N)

    local result
    result=$(run_query "SELECT count(*) FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 00:00:00' AND start_time < '2026-03-31 00:00:00' AND msisdn = '${SAMPLE_MSISDN}' FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    duration_ms=$((end_time - start_time))

    echo "$result"
    echo ""
    echo "客户端观测耗时: ${duration_ms} ms"

    # 获取详细统计
    echo ""
    echo "详细统计 (最近查询):"
    run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes,
    result_rows,
    formatReadableSize(memory_usage) as memory
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%SELECT count(*)%${table}%'
ORDER BY event_time DESC
LIMIT 1
FORMAT PrettyCompact
"
    echo ""
}

test_s1 "ods_traffic_records_local"
test_s1 "ods_traffic_records_local_new"

# 测试场景 2: 聚合查询
echo -e "${BLUE}[场景 S2] 聚合查询 - 按 app_type 分组统计${NC}"
echo ""

test_s2() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    run_query "SYSTEM DROP MARK CACHE" > /dev/null 2>&1

    local start_time end_time duration_ms
    start_time=$(date +%s%3N)

    local result
    result=$(run_query "SELECT app_type, count(*) as cnt, sum(up_bytes) as up, sum(down_bytes) as down FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 00:00:00' AND start_time < '2026-03-31 00:00:00' AND msisdn = '${SAMPLE_MSISDN}' GROUP BY app_type ORDER BY cnt DESC LIMIT 10 FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    duration_ms=$((end_time - start_time))

    echo "$result"
    echo ""
    echo "客户端观测耗时: ${duration_ms} ms"
    echo ""
}

test_s2 "ods_traffic_records_local"
test_s2 "ods_traffic_records_local_new"

# 测试场景 3: 小时粒度查询
echo -e "${BLUE}[场景 S3] 小时粒度查询 - toStartOfHour(start_time)${NC}"
echo ""

test_s3() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    run_query "SYSTEM DROP MARK CACHE" > /dev/null 2>&1

    local start_time end_time duration_ms
    start_time=$(date +%s%3N)

    local result
    result=$(run_query "SELECT toStartOfHour(start_time) as hour, count(*), sum(up_bytes) FROM ${CH_DB}.${table} WHERE toStartOfHour(start_time) = '2026-03-20 10:00:00' AND msisdn = '${SAMPLE_MSISDN}' GROUP BY hour FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    duration_ms=$((end_time - start_time))

    echo "$result"
    echo "客户端观测耗时: ${duration_ms} ms"
    echo ""
}

test_s3 "ods_traffic_records_local"
test_s3 "ods_traffic_records_local_new"

# 测试场景 4: 窄时间范围查询
echo -e "${BLUE}[场景 S4] 窄时间范围查询 - 验证排序键粒度影响${NC}"
echo "查询: 1分钟时间范围"
echo ""

test_s4() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    run_query "SYSTEM DROP MARK CACHE" > /dev/null 2>&1

    local start_time end_time duration_ms
    start_time=$(date +%s%3N)

    local result
    result=$(run_query "SELECT count(*), sum(up_bytes), sum(down_bytes) FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 10:00:00' AND start_time < '2026-03-20 10:01:00' AND msisdn = '${SAMPLE_MSISDN}' FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    duration_ms=$((end_time - start_time))

    echo "$result"
    echo "客户端观测耗时: ${duration_ms} ms"

    # 获取统计
    echo ""
    echo "详细统计:"
    run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes,
    formatReadableSize(memory_usage) as memory
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%SELECT count(*)%${table}%'
ORDER BY event_time DESC
LIMIT 1
FORMAT PrettyCompact
"
    echo ""
}

test_s4 "ods_traffic_records_local"
test_s4 "ods_traffic_records_local_new"

# 测试场景 5: 全表扫描压力测试
echo -e "${BLUE}[场景 S5] 压力测试 - 大范围时间查询${NC}"
echo "查询: 30天数据"
echo ""

test_s5() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    run_query "SYSTEM DROP MARK CACHE" > /dev/null 2>&1

    local start_time end_time duration_ms
    start_time=$(date +%s%3N)

    local result
    result=$(run_query "SELECT count(*), formatReadableSize(sum(up_bytes)), formatReadableSize(sum(down_bytes)) FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-01 00:00:00' AND start_time < '2026-04-01 00:00:00' FORMAT PrettyCompact")

    end_time=$(date +%s%3N)
    duration_ms=$((end_time - start_time))

    echo "$result"
    echo "客户端观测耗时: ${duration_ms} ms"

    # 获取统计
    echo ""
    echo "详细统计:"
    run_query "
SELECT
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes,
    formatReadableSize(memory_usage) as memory
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%SELECT count(*)%${table}%'
ORDER BY event_time DESC
LIMIT 1
FORMAT PrettyCompact
"
    echo ""
}

test_s5 "ods_traffic_records_local"
test_s5 "ods_traffic_records_local_new"

echo "==============================================="
echo "性能测试完成"
echo "==============================================="
