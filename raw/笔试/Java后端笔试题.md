# Java 后端笔试题



## 一、单选题

### 1. 关于 `volatile`，下面哪项说法是正确的？

```java
class Counter {
    private volatile int count = 0;

    public void inc() {
        count++;
    }
}
```

A. `volatile` 可以保证 `count++` 的原子性  
B. `volatile` 与 `AtomicInteger` 的效果完全等价  
C. `volatile` 可以保证可见性，但不能保证 `count++` 的原子性  
D. `count++` 在单机环境下一定线程安全

### 2. 下面关于 `synchronized` 锁对象的说法，哪项是正确的？

```java
class Demo {
    public synchronized void a() {}
    public static synchronized void b() {}
}
```

A. `a()` 锁住当前实例，`b()` 锁住 `Demo.class`  
B. `a()` 和 `b()` 使用的是同一把锁  
C. `a()` 锁住当前线程，`b()` 锁住当前类加载器  
D. 两者都只锁住方法代码块，不锁对象

### 3. 下面代码的输出结果是什么？

```java
public class Test {
    public static void main(String[] args) {
        byte b = 127;
        b += 1;
        System.out.println(b);
    }
}
```

A. `127`  
B. `128`  
C. `-128`  
D. 编译错误

### 4. 已知线程池参数如下，连续提交 7 个执行时间都很长的任务，不考虑任务提前结束。第 7 个任务会发生什么？

```java
ThreadPoolExecutor executor = new ThreadPoolExecutor(
        2,
        4,
        60,
        TimeUnit.SECONDS,
        new ArrayBlockingQueue<>(2),
        new ThreadPoolExecutor.AbortPolicy()
);
```

A. 第 7 个任务进入队列等待  
B. 第 7 个任务会触发拒绝策略并抛出异常  
C. 第 7 个任务会创建第 5 个工作线程执行  
D. 所有任务都会先进入队列，再由线程慢慢消费

### 5. 下面关于 `CompletableFuture.allOf(f1, f2, f3)` 的描述，哪项是正确的？

A. 它表示“所有任务都完成”这一事件，如果其中有任务异常，组合结果也可能异常结束  
B. 它会让 `f1`、`f2`、`f3` 自动串行执行  
C. 它会直接返回 `f1`、`f2`、`f3` 的结果列表  
D. 只要 `f1`、`f2`、`f3` 中任意一个完成，`allOf()` 就立即完成

### 6. 关于 `ConcurrentHashMap`，哪项说法是正确的？

A. 允许 `null` key，不允许 `null` value  
B. 允许 `null` key 和 `null` value  
C. 是否允许 `null` 与是否线程安全无关，JDK 没有限制  
D. 不允许 `null` key，也不允许 `null` value

### 7. 某接口需要分页查询 `user` 表数据，要求按 `id` 升序返回第 2 页，每页 10 条。下面哪条 SQL 是正确的？

A. `select * from user order by id asc limit 20, 10;`
B. `select * from user order by id asc limit 10, 10;`  
C. `select * from user order by id asc limit 2, 10;`  
D. `select * from user limit 2, 10 order by id asc;`  


### 8. 下面代码的输出结果是什么？

```java
public class Test {
    public static int test() {
        int x = 1;
        try {
            return x;
        } finally {
            x = 2;
        }
    }

    public static void main(String[] args) {
        System.out.println(test());
    }
}
```

A. `1`  
B. `2`  
C. 编译错误  
D. 运行异常

### 9. 下面代码的输出结果是什么？

```java
String s1 = "abc";
String s2 = "abc";
String s3 = new String("abc");

System.out.println(s1 == s2);
System.out.println(s1 == s3);
System.out.println(s1.equals(s3));
```

A. `true false true`  
B. `true true true`  
C. `false false true`  
D. `true false false`

### 10. 下面代码的输出结果是什么？

```java
public class Test {
    public static void change(int x, int[] arr) {
        x = 20;
        arr[0] = 20;
    }

    public static void main(String[] args) {
        int x = 10;
        int[] arr = {10};

        change(x, arr);
        System.out.println(x + "," + arr[0]);
    }
}
```

A. `10,10`  
B. `20,10`  
C. `20,20`  
D. `10,20`

## 二、多选题

### 1. 关于 Java 集合，哪些说法是正确的？

A. `ArrayList` 底层基于数组实现  
B. `HashSet` 中的元素允许重复  
C. `LinkedList` 既可以当作链表使用，也可以当作队列使用  
D. `HashMap` 的 key 允许为 `null`

### 2. 关于下面这段代码，哪些说法是正确的？

```java
List<String> list = new ArrayList<>();
list.add("A");
list.add("B");
list.add("C");

for (String s : list) {
    if ("B".equals(s)) {
        list.remove(s);
    }
}
```

A. `ArrayList` 会自动处理这种遍历期间删除，因此代码一定能正常运行  
B. 代码可以正常编译  
C. 代码运行时可能抛出 `ConcurrentModificationException`  
D. 把 `for-each` 改成显式迭代器，并使用 `iterator.remove()` 删除会更安全

### 3. 关于在线程池中使用 `ThreadLocal`，哪些说法是正确的？

A. 使用完后应及时 `remove()`，否则可能出现上下文串脏或内存泄漏问题  
B. 线程池里的线程会频繁复用，因此 `ThreadLocal` 数据可能跨请求残留  
C. 既然有 `ThreadLocal`，就可以完全替代线程间共享数据的同步方案  
D. `ThreadLocal` 适合保存单次请求链路中的上下文信息，但前提是生命周期管理清晰

## 三、简答题

### 1. 说明下面代码的输出，并解释原因。

```java
List<Integer> list = new ArrayList<>();
list.add(1);
list.add(2);
list.add(3);

list.remove(1);
System.out.println(list);
```








### 2. SQL 题

表：`orders`

| 字段名 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint | 订单 ID |
| user_id | bigint | 用户 ID |
| amount | decimal(10,2) | 订单金额 |
| create_time | datetime | 下单时间 |
| status | varchar | 订单状态，可能值为 `PAID`、`CANCELLED`、`REFUNDED` |

1. 查询满足以下条件的 `user_id`：

- `PAID` 状态的订单至少有 3 笔
- `PAID` 状态订单的总金额大于 1000
- 没有任何一笔 `CANCELLED` 状态订单

只返回 `user_id` 即可。

2. 查询每个用户最近一笔支付成功订单的 `user_id`、`id`、`create_time`；如果 `create_time` 相同，取 `id` 最大的一笔。










## 四、编程题

### 1. 实现一个线程安全单例。

要求：类名为 `Singleton`；需要延迟初始化；需要保证多线程环境下只创建一个实例；给出示例代码，并说明为什么这样写是线程安全的。
















### 2. 商场促销活动。

要求：满 100 全额打 9 折，满 500 全额打 8 折，满 2000 全额打 7 折，满 5000 全额打 6 折；不足 1 元部分不需要付款，按 `int` 强制类型转换处理。输入：账单钱数，`int` 类型。输出：优惠后应付钱数，`int` 类型。示例：输入 `654`，输出 `523`。














### 3. 实现一个简单阻塞队列。

要求：基于数组实现一个有界队列；提供 `put(int value)` 和 `take()` 方法；队列满时 `put` 阻塞等待，队列空时 `take` 阻塞等待；可以使用 `synchronized` 配合 `wait/notifyAll`；给出示例代码。









