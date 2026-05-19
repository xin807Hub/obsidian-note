--   1）总流量
SELECT
    '172.17.113.243' AS ip,
    sum(sum_total_byte) AS total_bytes,
    formatReadableSize(sum(sum_total_byte)) AS total_traffic
FROM NTA_DB_V4.dws_ip_session_1h_agg_view
WHERE (src_ip = '111.1.11.117' OR dst_ip = '111.1.11.117')
  AND agg_time >= '2026-04-01 17:00:00'
  AND agg_time <  '2026-04-02 09:00:00';


--   2）大类流量+大类名称 
SELECT
    app_type,
    dictGet('NTA_DICT_DB.app_type_dict', 'app_type_str', toUInt64(app_type)) AS app_type_name,
    sum(sum_total_byte) AS total_bytes,
    formatReadableSize(sum(sum_total_byte)) AS total_traffic
FROM NTA_DB_V4.dws_ip_session_1h_agg_view
WHERE (src_ip = '111.1.11.117' OR dst_ip = '111.1.11.117')
  AND agg_time >= '2026-04-01 17:00:00'
  AND agg_time <  '2026-04-02 09:00:00'
GROUP BY app_type
ORDER BY total_bytes DESC;


 --  3）小类流量
SELECT
    app_id,
    dictGet('NTA_DICT_DB.app_id_dict', 'app_id_str', toUInt64(app_id)) AS app_id_name,
    sum(sum_total_byte) AS total_bytes,
    formatReadableSize(sum(sum_total_byte)) AS total_traffic
FROM NTA_DB_V4.dws_ip_session_1h_agg_view
WHERE (src_ip = '111.1.11.117' OR dst_ip = '111.1.11.117')
  AND agg_time >= '2026-04-01 17:00:00'
  AND agg_time <  '2026-04-02 09:00:00'
GROUP BY app_id
ORDER BY total_bytes DESC;



-- 大类 + 小类 一起查 
SELECT
    app_type,
    dictGet('NTA_DICT_DB.app_type_dict', 'app_type_str', toUInt64(app_type)) AS app_type_name,
    app_id,
    dictGet('NTA_DICT_DB.app_id_dict', 'app_id_str', toUInt64(app_id)) AS app_id_name,
    sum(sum_total_byte) AS total_bytes,
    formatReadableSize(sum(sum_total_byte)) AS total_traffic
FROM NTA_DB_V4.dws_ip_session_1h_agg_view
WHERE (src_ip = '111.1.11.117' OR dst_ip = '111.1.11.117')
  AND agg_time >= '2026-04-01 17:00:00'
  AND agg_time <  '2026-04-02 09:00:00'
GROUP BY
    app_type,
    app_id
ORDER BY total_bytes DESC;
   
