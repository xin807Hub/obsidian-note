package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
)

// TestConfig 测试配置
type TestConfig struct {
	Host     string
	Port     int
	Database string
	Username string
	Password string
}

// TestResult 测试结果
type TestResult struct {
	Scenario    string
	Table       string
	DurationMs  float64
	ReadRows    uint64
	ReadBytes   uint64
	ResultRows  uint64
	ResultBytes uint64
	MemoryUsage uint64
	Query       string
	ExecutedAt  time.Time
}

func main() {
	config := TestConfig{
		Host:     "192.168.6.211",
		Port:     9000,
		Database: "TK_DB_SP",
		Username: "default",
		Password: "Ck@2o20...",
	}

	fmt.Println("=== ClickHouse 排序键优化性能测试 ===")
	fmt.Printf("连接: %s:%d/%s\n", config.Host, config.Port, config.Database)
	fmt.Println()

	// 连接数据库
	conn, err := connect(config)
	if err != nil {
		log.Fatalf("连接失败: %v", err)
	}
	defer conn.Close()

	// 测试连接
	if err := testConnection(conn); err != nil {
		log.Fatalf("连接测试失败: %v", err)
	}
	fmt.Println("✓ 数据库连接成功")
	fmt.Println()

	// 获取表基本信息
	if err := showTableInfo(conn, "ods_traffic_records_local"); err != nil {
		log.Printf("获取原表信息失败: %v", err)
	}
	if err := showTableInfo(conn, "ods_traffic_records_local_new"); err != nil {
		log.Printf("获取新表信息失败: %v", err)
	}
	fmt.Println()

	// 采集样本数据
	sampleMsisdns, err := getSampleMsisdns(conn)
	if err != nil || len(sampleMsisdns) == 0 {
		// 使用已知样本
		sampleMsisdns = []string{"381641449273"}
		fmt.Println("使用默认测试 msisdn:", sampleMsisdns[0])
	} else {
		fmt.Printf("采集到 %d 个样本 msisdn\n", len(sampleMsisdns))
	}

	// 获取时间范围
	timeRange, err := getTimeRange(conn)
	if err != nil {
		timeRange = struct {
			MinTime time.Time
			MaxTime time.Time
		}{
			MinTime: time.Date(2026, 3, 20, 0, 0, 0, 0, time.UTC),
			MaxTime: time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC),
		}
	}
	fmt.Printf("数据时间范围: %s ~ %s\n", timeRange.MinTime.Format("2006-01-02"), timeRange.MaxTime.Format("2006-01-02"))
	fmt.Println()

	// 执行测试场景
	var allResults []TestResult
	scenarios := []string{"S1", "S2", "S3", "S4", "S5"}

	for _, scenario := range scenarios {
		fmt.Printf("\n=== 场景 %s 测试 ===\n", scenario)
		results := runScenario(conn, scenario, sampleMsisdns, timeRange)
		allResults = append(allResults, results...)
	}

	// 生成报告
	generateReport(allResults)
}

func connect(config TestConfig) (driver.Conn, error) {
	addr := fmt.Sprintf("%s:%d", config.Host, config.Port)
	return clickhouse.Open(&clickhouse.Options{
		Addr: []string{addr},
		Auth: clickhouse.Auth{
			Database: config.Database,
			Username: config.Username,
			Password: config.Password,
		},
		DialTimeout:  30 * time.Second,
		MaxOpenConns: 5,
	})
}

func testConnection(conn driver.Conn) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return conn.Ping(ctx)
}

func showTableInfo(conn driver.Conn, tableName string) error {
	ctx := context.Background()

	fmt.Printf("\n--- 表 %s 信息 ---\n", tableName)

	// 查询表引擎和排序键
	query := fmt.Sprintf(`
		SELECT
			engine,
			partition_key,
			sorting_key,
			primary_key
		FROM system.tables
		WHERE database = 'TK_DB_SP' AND name = '%s'
	`, tableName)

	row := conn.QueryRow(ctx, query)
	var engine, partitionKey, sortingKey, primaryKey string
	if err := row.Scan(&engine, &partitionKey, &sortingKey, &primaryKey); err != nil {
		return err
	}

	fmt.Printf("引擎: %s\n", engine)
	fmt.Printf("分区键: %s\n", partitionKey)
	fmt.Printf("主键: %s\n", primaryKey)
	fmt.Printf("排序键: %s\n", sortingKey)

	// 查询表大小和行数
	sizeQuery := fmt.Sprintf(`
		SELECT
			formatReadableSize(sum(bytes)) as size,
			formatReadableQuantity(sum(rows)) as rows,
			count() as parts
		FROM system.parts
		WHERE database = 'TK_DB_SP' AND table = '%s' AND active
	`, tableName)

	sizeRow := conn.QueryRow(ctx, sizeQuery)
	var size, rows string
	var parts uint64
	if err := sizeRow.Scan(&size, &rows, &parts); err != nil {
		return err
	}

	fmt.Printf("数据大小: %s, 行数: %s, 活跃分区: %d\n", size, rows, parts)

	return nil
}

func getSampleMsisdns(conn driver.Conn) ([]string, error) {
	ctx := context.Background()
	query := `
		SELECT DISTINCT msisdn
		FROM ods_traffic_records_local
		WHERE msisdn != ''
		LIMIT 5
	`
	rows, err := conn.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msisdns []string
	for rows.Next() {
		var msisdn string
		if err := rows.Scan(&msisdn); err != nil {
			continue
		}
		msisdns = append(msisdns, msisdn)
	}

	return msisdns, nil
}

func getTimeRange(conn driver.Conn) (struct {
	MinTime time.Time
	MaxTime time.Time
}, error) {
	ctx := context.Background()
	query := `
		SELECT
			min(start_time) as min_time,
			max(start_time) as max_time
		FROM ods_traffic_records_local
	`

	row := conn.QueryRow(ctx, query)
	var result struct {
		MinTime time.Time
		MaxTime time.Time
	}

	err := row.Scan(&result.MinTime, &result.MaxTime)
	return result, err
}

func runScenario(conn driver.Conn, scenario string, msisdns []string, timeRange struct {
	MinTime time.Time
	MaxTime time.Time
}) []TestResult {
	var results []TestResult

	tables := []string{"ods_traffic_records_local", "ods_traffic_records_local_new"}

	for _, table := range tables {
		var query string
		var params []interface{}

		switch scenario {
		case "S1":
			// 基准查询 - 原截图场景
			query = fmt.Sprintf(`
				SELECT count(*)
				FROM %s
				WHERE start_time >= ?
				  AND start_time < ?
				  AND msisdn = ?
			`, table)
			params = []interface{}{
				timeRange.MinTime,
				timeRange.MaxTime,
				msisdns[0],
			}

		case "S2":
			// 多字段组合过滤
			query = fmt.Sprintf(`
				SELECT count(*), sum(up_bytes), sum(down_bytes)
				FROM %s
				WHERE start_time >= ?
				  AND start_time < ?
				  AND msisdn = ?
				  AND app_type > 0
			`, table)
			params = []interface{}{
				timeRange.MinTime,
				timeRange.MaxTime,
				msisdns[0],
			}

		case "S3":
			// 小时粒度查询
			hour := timeRange.MinTime.Truncate(time.Hour)
			query = fmt.Sprintf(`
				SELECT toStartOfHour(start_time) as hour, count(*), sum(up_bytes)
				FROM %s
				WHERE toStartOfHour(start_time) = ?
				  AND msisdn = ?
				GROUP BY hour
			`, table)
			params = []interface{}{hour, msisdns[0]}

		case "S4":
			// 多 msisdn IN 查询
			inMsisdns := msisdns
			if len(msisdns) < 3 {
				inMsisdns = append(inMsisdns, msisdns[0], msisdns[0])
			}
			placeholders := make([]string, len(inMsisdns))
			for i := range inMsisdns {
				placeholders[i] = "?"
				params = append(params, inMsisdns[i])
			}
			query = fmt.Sprintf(`
				SELECT msisdn, count(*)
				FROM %s
				WHERE start_time >= ?
				  AND start_time < ?
				  AND msisdn IN (%s)
				GROUP BY msisdn
			`, table, strings.Join(placeholders, ", "))
			params = append([]interface{}{timeRange.MinTime, timeRange.MaxTime}, params...)

		case "S5":
			// 聚合查询
			query = fmt.Sprintf(`
				SELECT app_type, app_id, count(*) as cnt, sum(up_bytes) as up, sum(down_bytes) as down
				FROM %s
				WHERE start_time >= ?
				  AND start_time < ?
				  AND msisdn = ?
				GROUP BY app_type, app_id
				ORDER BY cnt DESC
				LIMIT 10
			`, table)
			params = []interface{}{
				timeRange.MinTime,
				timeRange.MaxTime,
				msisdns[0],
			}
		}

		// 执行测试（3次取平均）
		var totalDuration time.Duration
		var lastResult TestResult

		for i := 0; i < 3; i++ {
			result := executeQuery(conn, query, params, scenario, table)
			totalDuration += time.Duration(result.DurationMs * float64(time.Millisecond))
			lastResult = result

			// 第一次执行后清除缓存（通过 SYSTEM DROP MARK CACHE 等）
			if i == 0 {
				dropCache(conn)
			}
		}

		// 计算平均值
		avgDuration := float64(totalDuration) / float64(3*time.Millisecond)
		lastResult.DurationMs = avgDuration

		results = append(results, lastResult)

		fmt.Printf("  %s: %.2f ms, read_rows=%d, read_bytes=%s\n",
			table,
			lastResult.DurationMs,
			lastResult.ReadRows,
			formatBytes(lastResult.ReadBytes))
	}

	return results
}

func executeQuery(conn driver.Conn, query string, params []interface{}, scenario, table string) TestResult {
	ctx := context.Background()

	start := time.Now()
	rows, err := conn.Query(ctx, query, params...)
	elapsed := time.Since(start)

	result := TestResult{
		Scenario:   scenario,
		Table:      table,
		DurationMs: float64(elapsed) / float64(time.Millisecond),
		Query:      query,
		ExecutedAt: time.Now(),
	}

	if err != nil {
		log.Printf("查询失败: %v", err)
		return result
	}
	defer rows.Close()

	// 消费结果
	for rows.Next() {
		// 简单扫描但不处理值
	}

	// 获取统计信息
	statsQuery := `
		SELECT
			query_duration_ms,
			read_rows,
			read_bytes,
			result_rows,
			result_bytes,
			memory_usage
		FROM system.query_log
		WHERE type = 'QueryFinish'
		ORDER BY event_time_microseconds DESC
		LIMIT 1
	`

	// 等待日志写入
	time.Sleep(100 * time.Millisecond)

	statRow := conn.QueryRow(ctx, statsQuery)
	var durationMs float64
	var readRows, readBytes, resultRows, resultBytes, memoryUsage uint64

	if err := statRow.Scan(&durationMs, &readRows, &readBytes, &resultRows, &resultBytes, &memoryUsage); err == nil {
		result.DurationMs = durationMs
		result.ReadRows = readRows
		result.ReadBytes = readBytes
		result.ResultRows = resultRows
		result.ResultBytes = resultBytes
		result.MemoryUsage = memoryUsage
	}

	return result
}

func dropCache(conn driver.Conn) {
	ctx := context.Background()
	// 尝试清除缓存
	_ = conn.Exec(ctx, "SYSTEM DROP MARK CACHE")
	_ = conn.Exec(ctx, "SYSTEM DROP UNCOMPRESSED CACHE")
}

func formatBytes(b uint64) string {
	const unit = 1024
	if b < unit {
		return fmt.Sprintf("%d B", b)
	}
	div, exp := uint64(unit), 0
	for n := b / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(b)/float64(div), "KMGTPE"[exp])
}

func generateReport(results []TestResult) {
	fmt.Println("\n\n========== 性能测试报告 ==========\n")

	// 按场景分组
	scenarioGroups := make(map[string][]TestResult)
	for _, r := range results {
		scenarioGroups[r.Scenario] = append(scenarioGroups[r.Scenario], r)
	}

	for scenario, group := range scenarioGroups {
		fmt.Printf("\n【场景 %s】\n", scenario)
		fmt.Println(strings.Repeat("-", 80))

		var oldResult, newResult *TestResult
		for i := range group {
			if group[i].Table == "ods_traffic_records_local" {
				oldResult = &group[i]
			} else {
				newResult = &group[i]
			}
		}

		if oldResult != nil && newResult != nil {
			// 计算提升比例
			durationRatio := oldResult.DurationMs / newResult.DurationMs
			readRowsRatio := float64(oldResult.ReadRows) / float64(newResult.ReadRows)
			readBytesRatio := float64(oldResult.ReadBytes) / float64(newResult.ReadBytes)

			fmt.Printf("%-25s %15s %15s %10s\n", "指标", "优化前", "优化后", "提升倍数")
			fmt.Println(strings.Repeat("-", 80))
			fmt.Printf("%-25s %15.2f %15.2f %10.1fx\n", "查询耗时(ms)", oldResult.DurationMs, newResult.DurationMs, durationRatio)
			fmt.Printf("%-25s %15d %15d %10.1fx\n", "读取行数", oldResult.ReadRows, newResult.ReadRows, readRowsRatio)
			fmt.Printf("%-25s %15s %15s %10.1fx\n", "读取字节", formatBytes(oldResult.ReadBytes), formatBytes(newResult.ReadBytes), readBytesRatio)
			fmt.Printf("%-25s %15d %15d\n", "结果行数", oldResult.ResultRows, newResult.ResultRows)
			fmt.Printf("%-25s %15s %15s\n", "内存使用", formatBytes(oldResult.MemoryUsage), formatBytes(newResult.MemoryUsage))
		}
	}

	// 保存结果到文件
	reportFile := fmt.Sprintf("performance_report_%s.md", time.Now().Format("20060102_150405"))
	f, err := os.Create(reportFile)
	if err != nil {
		log.Printf("无法创建报告文件: %v", err)
		return
	}
	defer f.Close()

	fmt.Fprintf(f, "# ClickHouse 排序键优化 - 性能测试报告\n\n")
	fmt.Fprintf(f, "测试时间: %s\n\n", time.Now().Format("2006-01-02 15:04:05"))

	for scenario, group := range scenarioGroups {
		fmt.Fprintf(f, "## 场景 %s\n\n", scenario)
		fmt.Fprintf(f, "| 表名 | 耗时(ms) | 读取行数 | 读取字节 | 内存使用 |\n")
		fmt.Fprintf(f, "|------|----------|----------|----------|----------|\n")

		for _, r := range group {
			fmt.Fprintf(f, "| %s | %.2f | %d | %s | %s |\n",
				r.Table, r.DurationMs, r.ReadRows, formatBytes(r.ReadBytes), formatBytes(r.MemoryUsage))
		}
		fmt.Fprintf(f, "\n")
	}

	fmt.Printf("\n\n报告已保存到: %s\n", reportFile)
}
