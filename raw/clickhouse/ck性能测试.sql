-- 1、查询已完成sql的耗时、内存等指标：
select event_time_microseconds,
       query,
       query_start_time,
       query_duration_ms,
       written_rows,
       formatReadableSize(memory_usage),
       `tables`,
       type
from system.query_log
where query_start_time >= '2025-11-14 11:40:00'
  and type in ['QueryFinish', 'ExceptionBeforeStart', 'ExceptionWhileProcessing']
order by query_duration_ms desc
limit 50;


-- 2、间隔5分钟方式统计ck内存峰值：
with interval 5 minute as time_frame_size -- 时间间隔，当前是5分钟
        , 100 as bar_width                -- 条状图的宽度，当前是100
        , (select max(value) from system.asynchronous_metric_log where metric = 'OSMemoryTotal') as max_mem
        , now() - interval 72 hour as time_start
        , now() as time_end
select toStartOfInterval(event_time, time_frame_size) as timeframe,
       max(value)                                     as `used_memory`,
       formatReadableSize(`used_memory`)              as `used_memory_readable`,
       formatReadableSize(max_mem)                    as `max_memory`,
       bar(used_memory / max_mem, 0, 1, bar_width)
from system.asynchronous_metric_log
where metric = 'MemoryResident'
  and event_time >= time_start
  and event_time <= time_end
--where metric = 'MemoryResident' and event_time >= '2025-07-02 15:40:00' and event_time <= '2025-07-03 01:40:00'
group by timeframe
order by timeframe desc;


-- 3、粗略统计各种sql内存平均消耗：
with now() - interval 72 hour as time_start -- 开始时间
        , now() as time_end                 -- 结束时间
select any(query),
       count()                               as `出现次数`,
       avg(memory_usage)                     as avg_memory_usage,
       formatReadableSize(avg(memory_usage)) as `平均内存使用`
from system.query_log
where type = 'QueryFinish'
  and event_time_microseconds >= time_start
  and event_time_microseconds <= time_end
group by normalizedQueryHash(query)
order by avg_memory_usage desc
limit 100;


-- 4、粗略统计各种sql平均耗时：
with now() - interval 72 hour as time_start, -- 开始时间
    now() as time_end                        -- 结束时间
select any(query),
       count()                as `出现次数`,
       avg(query_duration_ms) as avg_duration_ms
from system.query_log
where type = 'QueryFinish'
  and event_time_microseconds >= time_start
  and event_time_microseconds <= time_end
group by normalizedQueryHash(query)
order by avg_duration_ms desc
limit 50
;



--参考链接
--https://zhuanlan.zhihu.com/p/672164657


