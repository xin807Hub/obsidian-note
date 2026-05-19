# Java后端笔试题-快速批阅版

对应题面：[Java后端笔试题.md](/D:/code/cxGo/docs/笔试/Java后端笔试题.md)

批阅建议：单选/多选直接对答案；简答题按核心点给分；编程题先看并发安全和边界，再看代码是否简洁。

## 一、单选题

1. C
2. A
3. C
4. B
5. A
6. D
7. B
8. A
9. A
10. D

## 二、多选题

1. A、C、D
2. B、C、D
3. A、B、D

## 三、简答题

### 1. `list.remove(1)` 输出

标准答案：

```text
[1, 3]
```

给分点：

- `remove(1)` 命中的是 `remove(int index)`，不是 `remove(Object)`
- 删除的是索引 `1` 位置的元素，即值 `2`
- 如果要删除值 `1`，应写成 `remove(Integer.valueOf(1))`

### 2. SQL 题

第 1 问标准答案：

```sql
select user_id
from orders
group by user_id
having sum(case when status = 'PAID' then 1 else 0 end) >= 3
   and sum(case when status = 'PAID' then amount else 0 end) > 1000
   and sum(case when status = 'CANCELLED' then 1 else 0 end) = 0;
```

第 2 问标准答案：

```sql
select user_id, id, create_time
from (
    select user_id,
           id,
           create_time,
           row_number() over (
               partition by user_id
               order by create_time desc, id desc
           ) as rn
    from orders
    where status = 'PAID'
) t
where rn = 1;
```

速判标准：

- 第 1 问必须同时满足“至少 3 笔已支付”“已支付总金额 > 1000”“没有取消单”
- 若先 `where status = 'PAID'` 再去判断“没有 CANCELLED”，不给满分
- 第 2 问必须处理 `create_time` 相同取 `id` 最大

## 四、编程题

### 1. 线程安全单例

关键给分点：

- 延迟初始化
- 并发下只创建一次
- 双重检查时使用 `volatile`

参考实现：

```java
public class Singleton {
    private static volatile Singleton instance;

    private Singleton() {
    }

    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

### 2. 商场促销活动

关键给分点：

- 按金额区间从高到低判断
- 使用全额折扣，不是减免
- 结果按 `int` 截断

参考实现：

```java
public class Main {
    public static int calculate(int amount) {
        double discount = 1.0;

        if (amount >= 5000) {
            discount = 0.6;
        } else if (amount >= 2000) {
            discount = 0.7;
        } else if (amount >= 500) {
            discount = 0.8;
        } else if (amount >= 100) {
            discount = 0.9;
        }

        return (int) (amount * discount);
    }
}
```

### 3. 简单阻塞队列

关键给分点：

- 基于数组
- `put` 满时等待
- `take` 空时等待
- 使用 `while` 配合 `wait/notifyAll`
- 入队出队索引正确维护

参考实现：

```java
public class BlockingQueue {
    private final int[] data;
    private int head = 0;
    private int tail = 0;
    private int size = 0;

    public BlockingQueue(int capacity) {
        this.data = new int[capacity];
    }

    public synchronized void put(int value) throws InterruptedException {
        while (size == data.length) {
            wait();
        }

        data[tail] = value;
        tail = (tail + 1) % data.length;
        size++;
        notifyAll();
    }

    public synchronized int take() throws InterruptedException {
        while (size == 0) {
            wait();
        }

        int value = data[head];
        head = (head + 1) % data.length;
        size--;
        notifyAll();
        return value;
    }
}
```
