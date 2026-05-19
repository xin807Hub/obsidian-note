#!/bin/bash

# ClickHouse 性能测试脚本 (使用 HTTP 接口)
# 服务器: 192.168.6.211:8123
# 数据库: TK_DB_SP

CH_HOST="192.168.6.211"
CH_PORT="8123"
CH_USER="default"
CH_PASS="Ck@2o20..."
CH_DB="TK_DB_SP"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 构建基础 URL
BASE_URL="http://${CH_USER}:${CH_PASS}@${CH_HOST}:${CH_PORT}/"

echo "==============================================="
echo "ClickHouse 排序键优化 - 性能测试"
echo "==============================================="
echo "连接: ${CH_HOST}:${CH_PORT}/${CH_DB}"
echo ""

# 测试连接
echo "[1] 测试数据库连接..."
curl -s "${BASE_URL}" -d "SELECT 1" > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 连接成功${NC}"
else
    echo -e "${RED}✗ 连接失败${NC}"
    exit 1
fi
echo ""

# 获取表信息
echo "[2] 获取表基本信息..."
echo ""
echo "--- ods_traffic_records_local (优化前) ---"
curl -s "${BASE_URL}" -d "
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
curl -s "${BASE_URL}" -d "
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
curl -s "${BASE_URL}" -d "
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
SAMPLE_MSISDN=$(curl -s "${BASE_URL}" -d "SELECT msisdn FROM ${CH_DB}.ods_traffic_records_local WHERE msisdn != '' LIMIT 1 FORMAT TSVRaw")
echo "样本 MSISDN: ${SAMPLE_MSISDN}"
echo ""

# 获取时间范围
echo "[5] 数据时间范围..."
curl -s "${BASE_URL}" -d "
SELECT
    min(start_time) as min_time,
    max(start_time) as max_time
FROM ${CH_DB}.ods_traffic_records_local
FORMAT PrettyCompact
"
echo ""

# 测试场景 1: 基准查询 (原截图场景)
echo "==============================================="
echo "[场景 S1] 基准查询 - 时间范围 + msisdn 精确匹配"
echo "查询: SELECT count(*) FROM table WHERE start_time >= '2026-03-20' AND start_time < '2026-03-31' AND msisdn = '${SAMPLE_MSISDN}'"
echo "==============================================="
echo ""

run_benchmark_s1() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    # 清除缓存
    curl -s "${BASE_URL}" -d "SYSTEM DROP MARK CACHE" > /dev/null
    curl -s "${BASE_URL}" -d "SYSTEM DROP UNCOMPRESSED CACHE" > /dev/null

    # 执行查询并获取统计
    local result
    result=$(curl -s "${BASE_URL}" -d "
WITH
    (SELECT count() FROM ${CH_DB}.${table} WHERE start_time >= '2026-03-20 00:00:00' AND start_time < '2026-03-31 00:00:00' AND msisdn = '${SAMPLE_MSISDN}') as cnt,
    (SELECT query_duration_ms FROM system.query_log WHERE type = 'QueryFinish' ORDER BY event_time DESC LIMIT 1) as duration,
    (SELECT read_rows FROM system.query_log WHERE type = 'QueryFinish' ORDER BY event_time DESC LIMIT 1) as read_rows,
    (SELECT read_bytes FROM system.query_log WHERE type = 'QueryFinish' ORDER BY event_time DESC LIMIT 1) as read_bytes
SELECT
    cnt as result_count,
    duration as query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as read_bytes
FORMAT PrettyCompact
")
    echo "$result"
    echo ""
}

run_benchmark_s1 "ods_traffic_records_local"
run_benchmark_s1 "ods_traffic_records_local_new"

# 测试场景 2: 多字段聚合
echo "==============================================="
echo "[场景 S2] 聚合查询 - 按 app_type, app_id 分组统计"
echo "==============================================="
echo ""

run_benchmark_s2() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    curl -s "${BASE_URL}" -d "SYSTEM DROP MARK CACHE" > /dev/null

    local start_time end_time
    start_time=$(date +%s%N)

    curl -s "${BASE_URL}" -d "
SELECT app_type, app_id, count(*) as cnt, sum(up_bytes) as up, sum(down_bytes) as down
FROM ${CH_DB}.${table}
WHERE start_time >= '2026-03-20 00:00:00'
  AND start_time < '2026-03-31 00:00:00'
  AND msisdn = '${SAMPLE_MSISDN}'
GROUP BY app_type, app_id
ORDER BY cnt DESC
LIMIT 10
FORMAT PrettyCompact
"

    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    echo "客户端观测耗时: ${duration_ms} ms"
    echo ""
}

run_benchmark_s2 "ods_traffic_records_local"
run_benchmark_s2 "ods_traffic_records_local_new"

# 测试场景 3: 小时粒度查询
echo "==============================================="
echo "[场景 S3] 小时粒度查询 - toStartOfHour(start_time)"
echo "==============================================="
echo ""

run_benchmark_s3() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    curl -s "${BASE_URL}" -d "SYSTEM DROP MARK CACHE" > /dev/null

    local start_time end_time
    start_time=$(date +%s%N)

    curl -s "${BASE_URL}" -d "
SELECT toStartOfHour(start_time) as hour, count(*), sum(up_bytes)
FROM ${CH_DB}.${table}
WHERE toStartOfHour(start_time) = '2026-03-20 10:00:00'
  AND msisdn = '${SAMPLE_MSISDN}'
GROUP BY hour
FORMAT PrettyCompact
"

    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    echo "客户端观测耗时: ${duration_ms} ms"
    echo ""
}

run_benchmark_s3 "ods_traffic_records_local"
run_benchmark_s3 "ods_traffic_records_local_new"

# 测试场景 4: 精确时间戳查询（测试排序键时间粒度差异）
echo "==============================================="
echo "[场景 S4] 秒级时间范围查询 - 验证排序键粒度影响"
echo "==============================================="
echo ""

run_benchmark_s4() {
    local table=$1
    echo "--- 测试表: ${table} ---"

    curl -s "${BASE_URL}" -d "SYSTEM DROP MARK CACHE" > /dev/null

    local start_time end_time
    start_time=$(date +%s%N)

    curl -s "${BASE_URL}" -d "
SELECT count(*), sum(up_bytes), sum(down_bytes)
FROM ${CH_DB}.${table}
WHERE start_time >= '2026-03-20 10:00:00'
  AND start_time < '2026-03-20 10:01:00'
  AND msisdn = '${SAMPLE_MSISDN}'
FORMAT PrettyCompact
"

    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    echo "客户端观测耗时: ${duration_ms} ms"
    echo ""
}

run_benchmark_s4 "ods_traffic_records_local"
run_benchmark_s4 "ods_traffic_records_local_new"

echo "==============================================="
echo "性能测试完成"
echo "==============================================="
