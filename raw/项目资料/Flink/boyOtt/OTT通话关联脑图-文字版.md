# OTT关联

## OTT语音通话关联

### 涉及组件

#### dpi
- 根据协议识别输出OTT通话文本话单

#### WhatsApp
- `caller_type`
- 均为0
- `caller_tag`
- 流新建的时间
- 平台判断谁小谁就是主叫

#### Signal
- `caller_type`
- `1`：主叫
- `2`：被叫
- 空
- `caller_tag`
- 均为空

#### Viber
- `caller_type`
- `1`：主叫
- `2`：被叫
- 空
- `caller_tag`
- 均为空

#### Telegram
- `caller_type`
- 均为0
- `caller_tag`
- 命中17-18185-5特征的UDP载荷第一字节
- 平台判断谁小谁就是主叫

#### wechat
- `caller_type`
- `1`：主叫
- `2`：被叫
- 空
- `caller_tag`
- 均为空

#### discord
- `caller_type`
- 均为0
- `caller_tag`
- 流新建的时间
- 平台判断谁小谁就是主叫

#### line
- `caller_type`
- 均为0
- `caller_tag`
- 流新建的时间
- 平台判断谁小谁就是主叫

#### [老方案]ott_correlate
- 处理OTT通话文本话单，关联上之后，将数据写入数据库OTT通话关联表，同时原始日志也入库

#### [新方案]flink
- 直接接收所有DPI发送过来的关联话单，

### 关联原理

#### session_id关联（whatsapp/signal/viber/telegram）
- `1` session_ID为key建map，超时对seesion_ID相同的做关联输出
- 当一端出现1或者2，另外一端为0时，优先取有值的一端，另外一端为对应的2或者1
- 遗留：在不同时间窗口过来会输出多条
- 取duration最大的那条记录作为合并后的记录
- duration相等的时候取值主叫记录
- starttime和endtime取这条记录里面的值
- 遗留：通话时间可能比实际的小
- 对于Whatsapp而言，主叫和被叫都会出两条不同sessionID的话单，通过最大的duration，可以保证主被叫的起始时间和结束时间一样

- `2` 入库之前对这一批次的，如果发现开始时间、结束时间、应用以及源IP(排序)一样的，做合并
- 为什么不带sessionID，因为whatsapp会有两个不同sessionID
- 加个WhatsApp应用的判断，来做这个合并逻辑

- `3` API查询时，对相同session_ID的取第一条（统计级的数据展示）
- 优化：取持续时间最大的那条记录
- 优化2：主被叫方向优先取caller_type有值的

- `4` API查询时，对相同session_ID、应用、主被叫的源IP做的合并，值随机取一条（日志列表展示）
- 优化：和上面的合并逻辑保持一致，取持续时间最大的那条记录

#### 上下行ssrc/seq/time关联（discord/line）
- 上下行ssrc为key建map：主被叫上下行相反，DPI侧根据第一个包含ssrc的包，如果为server端发起，则做反向处理；最终汇总成一个字段，复用之前的session_id字段；
- 相同得ssrc得条目，比对seq/time是否在相同得区间内，在相同区间内则关联输出
- 主被叫均以caller_tag值来判断，谁小谁就是主叫

### 特殊场景

#### 多条相同session_ID

##### 同一开始时间
- 结束时间相同
- 关联原理1
- 结束时间不同
- 关联原理1
- 遗留：跨窗口时，有一条没有主被叫信息时，可能会导致主被叫有误

##### 不同开始时间
- 遗留：跨窗口时，有一条没有主被叫信息时，可能会导致主被叫有误
- 典型示例：44s的telegram

#### 多条不同session_ID

##### 同一开始时间
- Whatsapp
- 关联原理的2
- 其他未发现

##### 不同时间
- 正常处理逻辑，正常关联
- 待解决
- 典型示例：39s的viber

## OTT视频通话关联

### 涉及组件

#### whatsapp
- 根据stun的src ip+port来关联signal的音频流，关联上则为视频

#### signal
- 根据stun的src ip+port来关联signal的音频流，关联上则为视频

#### viber
- 视频关联和音频关联逻辑相同，仅根据平均包大小区分音视频

#### telegram
- `1` 提取udp心跳流的username
- `2` 提取channel data中的username
- `3` 提取stun rtp中的username
- `4` 关联1和2/3，并根据平均包大小判断音视频

#### wechat
- 视频关联和音频关联逻辑相同，仅根据平均包大小区分音视频

#### discord
- 视频关联和音频关联逻辑相同，仅根据平均包大小区分音视频

#### line
- 视频关联和音频关联逻辑相同，仅根据平均包大小区分音视频

## OTT文件关联

### 涉及组件

#### DPI
- 根据协议识别输出OTT文件关联话单，根据上下行流量大小识别为上传或者下载
- HTTPS
- 结束seq减去开始seq
- QUIC
- 每帧减去固定字节

#### ott_correlate
- 处理OTT通话文本话单，关联上之后，将数据写入数据库OTT文件关联表，同时原始日志也入库

### 关联原理

#### `1` 周期性的读取ott文件关联话单，过滤file_size_min的话单，按照文件大小排序，存入表中

#### `2` 定时器周期性扫描链表，发现有超时的上传节点时(time_now>=日志end_time+ott_timeout)，准备进行关联操作
- Telegram
- 相同手机号+应用大小类的在10ms之内的进行合并操作
- 其他

#### `3` 过滤在偏差范围内的日志
- `P0` 优先选择在三层访问关系之内的日志
- 如果有多个，则走P1逻辑
- `P1` 其次选择坐标点距离最近的日志
- 如果多个，随机取一个

### 特殊场景
- 一条流发送多个文件暂无法解决

## 实时跟踪

### 涉及组件

#### DPI
- 老方案：UDP的方式发送日志给ott_realtime
- 场景1：带有communicationID的
- 可展示通话双方
- 场景2：全量的日志
- 可以展示地理位置
- 新方案：SDTP的方式发送给filink
- 场景1：带有communicationID的
- 场景2：全量的日志（开关控制）

#### ott_realtime(老方案)
- 接收DPI的实时消息，提供WEB调用的实时关联查询接口

#### filink(新方案)
- 接收DPI的实时消息，将关联结果写入redis数据库

#### tk_server(新方案)
- 提供WEB调用的实时关联查询接口，从redis数据库查询数据

### 关联原理

#### `1` 以communicationID/msisdn为key分开建立map，有communicationID的日志放入对应的map，没有的则以msisdn为key放入另外一个map

#### `2` 主被叫的判断逻辑和语音通话逻辑一致
- 老方案：数据存在map中
- 新方案：数据存在redis数据库中

#### `3` 对外提供API查询接口
- 老方案：ott_realtime查询后返回
- 先查communicationID的map（遍历方式），再查msisdn的map（开关控制）
- 新方案：直接查redis数据库

## 虚实关联

### 涉及组件

#### DPI
- 根据协议识别twitter media upload，输出所有有X(twitter)的上传话单

#### tk_server
- 下发爬取任务给tk_crawler_server

#### tk_crawler_server
- 接收爬取任务，执行爬取任务，返回爬取结果给ott_correlate

#### ott_correlate
- 接收tk_crawler_server的爬取结果，从DPI话单中匹配日志

### 关联原理
- `1` DPI根据协议识别，输出所有的twitter media upload话单
- `2` 爬虫脚本根据web下发的爬虫任务，去爬取用户的发帖（图片和视频）信息，将时间序列返回给ott_correlate
- `3` ott_correlate根据时间序列信息，去数据库中查询同一手机号相关日志（时间误差在vr_time_range之内）
