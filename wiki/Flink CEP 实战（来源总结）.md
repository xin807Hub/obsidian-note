# Flink CEP 实战（来源总结）

## 来源信息

- 原文：[raw/Flink CEP 实战：5分钟学会复杂事件处理，让数据流“动”出智能！.md](../raw/Flink%20CEP%20实战：5分钟学会复杂事件处理，让数据流“动”出智能！.md)
- 主题：以入门视角介绍 [[Flink CEP]] 的定义、核心概念、基础语法、典型场景与实践注意事项

## 核心结论

[[Flink CEP]] 适合处理“单条事件无法表达完整业务逻辑”的实时场景。它通过定义事件模式、约束事件间的条件与时间关系，在连续事件流中识别出有业务意义的行为序列，并触发告警、推荐、风控等动作。

原文的核心判断可以概括为：

- [[复杂事件处理（CEP）]] 关注的不是单点事件，而是事件之间的组合关系和先后顺序。
- [[Flink CEP]] 将复杂行为识别从手写状态机逻辑中抽象为声明式模式定义。
- 在涉及时序判断时，应优先使用 [[事件时间（Event Time）]]，并结合 [[Watermark]] 处理乱序事件。
- CEP 特别适合实时风控、用户意图识别、异常交易检测等“模式命中即动作触发”的场景。

## 关键概念提炼

### 1. [[复杂事件处理（CEP）]]

通过识别多个事件在顺序、条件、时间窗口上的组合关系，发现更高层的业务语义。

### 2. [[Flink CEP]]

Flink 提供的 CEP 库，用于在流式处理任务中声明模式、匹配事件、输出命中结果。

### 3. Pattern / Condition / Within

这是原文反复强调的三件套：

- Pattern：定义希望匹配的事件序列结构
- Condition：约束每个阶段的事件条件
- Within：限制整段匹配必须发生在给定时间窗口内

### 4. [[事件时间（Event Time）]]

按事件真实发生时间来做判断，更适合业务语义准确性要求高的流处理任务。

### 5. [[Watermark]]

用于告诉系统“某个时间点之前的数据大概率已经到齐”，从而在乱序场景下仍能稳定推进计算。

## 原文中的典型应用场景

- 风控：10 分钟内连续 3 次登录失败，触发安全告警
- 营销：5 分钟内多次浏览同一商品，推送优惠券
- 支付监控：1 分钟内多次相同金额下单，触发人工审核

这些场景的共性是：都不是单个事件是否异常，而是“事件序列是否构成某种模式”。

## 实现流程速记

原文给出的实现链路可以抽象为：

1. 定义输入事件流
2. 定义匹配模式
3. 将模式应用到按业务主键分组后的流上
4. 在模式命中后输出处理结果

对应的最小思路是：

```java
Pattern<Event, ?> pattern = Pattern.<Event>begin("first")
    .where(event -> event.getType().equals("login_fail"))
    .next("second")
    .where(event -> event.getType().equals("login_fail"))
    .next("third")
    .where(event -> event.getType().equals("login_fail"))
    .within(Time.minutes(10));

PatternStream<Event> patternStream =
    CEP.pattern(eventStream.keyBy(Event::getUserId), pattern);
```

## 实践注意事项

- 时间窗口过宽，会增加状态保留时长和内存压力
- [[Watermark]] 过宽，会拉高整体检测延迟
- 若需要严格连续匹配，可考虑使用更严格的匹配策略，避免重复告警
- 调试 CEP 时，尽量输出中间匹配信息，而不是只看最终命中结果

## 相关页面

- [[Flink CEP]]
- [[复杂事件处理（CEP）]]
- [[事件时间（Event Time）]]
- [[Watermark]]
