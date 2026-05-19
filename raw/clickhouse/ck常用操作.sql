-- 查询系统表信息
SELECT
    sum(rows) AS `总行数`,
    formatReadableSize(sum(data_uncompressed_bytes)) AS `原始大小`,
    formatReadableSize(sum(data_compressed_bytes)) AS `压缩大小`,
    round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100, 0) AS `压缩率`,
    table AS `表名`
FROM system.parts
where database = 'TK_DB_V2'
GROUP BY table
ORDER BY `压缩大小` ASC
;




-- 修正表名
SELECT
    a.`表名`, b.table as `join表名`, a.`总行数`, a.`原始大小`, a.`压缩大小`, a.`压缩率`
FROM
    (
        SELECT
            sum(rows) AS `总行数`,
            formatReadableSize(sum(data_uncompressed_bytes)) AS `原始大小`,
            formatReadableSize(sum(data_compressed_bytes)) AS `压缩大小`,
            sum(data_compressed_bytes) as sum_compressed_bytes,
            if(startsWith(table, '.inner_id.'), substring(table, 11, length(table) - 10), '') as uuid,
            round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100, 0) AS `压缩率`,
            table AS `表名`
        FROM system.parts
        GROUP BY table
        ORDER BY sum_compressed_bytes
        ) a
        left JOIN
    (
        select database, name, table, toString(uuid) as uuid_s from system.tables
        ) b
    on a.uuid=b.uuid_s;








--查看未合并分区情况:
select table, countIf(active=1) from system.parts group by table;



-- merge状态查看
SELECT

    thread_id,
    database,
    table,
    round(elapsed, 2) AS time_use,
    round(progress, 2) AS progress,
    num_parts,
    formatReadableSize(total_size_bytes_compressed) AS total_size_bytes_compressed_GB,
    formatReadableSize(bytes_read_uncompressed) AS bytes_read_uncompressed_GB,
    rows_read / 10000 AS rows_read_w,
    rows_written / 10000000 AS rows_written_kw,
    formatReadableSize(memory_usage) AS memory_usage_MB
FROM system.merges
ORDER BY time_use DESC





-- 查看集群信息

select * from system.clusters;



-- 设置TTL

alter table com_table_local modify TTL log_time + toIntervalMonth(1);





-- 删除数据

alter table com_table_local delete where log_time<='2023-04-10';

alter table com_table_local drop partition '20230401';





-- 查看setting

show settings like '%merge%';



-- 设置参数

SET receive_timeout=6000;





-- csv导入导出

-- 导出：

clickhouse-client -m -udefault --password=1qaz2wsx -q "select * from DPI_DB.app_id_day_list limit 1000 FORMAT CSV" > app_id_day_list.csv

(指定分隔符: clickhouse-client -m -udefault --password=1qaz2wsx --format_csv_delimiter="|" -q "select * from DPI_DB.app_id_day_list limit 1000 FORMAT CSV" > app_id_day_list.csv)



--mysql csv导出：

mysql -uroot -p -h10.250.xxx.xxx app -A -e "select * from  xxx" | sed 's/\t/","/g;s/^/"/;s/$/"/;s/\n//g' >>outfile.csv





--导入：

clickhouse-client -m -udefault --password=RootSi314 --port=9900 -q "insert into DPI_DB.app_id_day_list FORMAT CSV" <./app_id_day_list.csv



--执行sql文件：

clickhouse-client -udefault --password=123456 -d NTA_DB --multiquery < clickhouse.sql





-- 常用ClickHouse问题诊断查询：

http://192.168.5.229/pages/createpage.action?spaceKey=~wangqun&fromPageId=1146971

https://zhuanlan.zhihu.com/p/672164657


-- 查询最近的一天的 sql 执行速度
SELECT
    event_time_microseconds,
    query,
    query_start_time,
    query_duration_ms,
    written_rows,
    formatReadableSize (memory_usage),
    `tables`,
    type
FROM system.query_log
WHERE query_start_time >= '2025-11-14 09:00:00'
AND type in ['QueryFinish', 'ExceptionBeforeStart', 'ExceptionWhileProcessing']
ORDER BY
query_duration_ms DESC
limit 50
;


-- 未合并分区
SELECT table, countIf(active=1) as no_merge_num
FROM system.parts
GROUP BY table;



