# Go笔试题目-快速批阅版

对应题面：[GO笔试题目.md](/D:/code/cxGo/docs/笔试/GO笔试题目.md)

批阅建议：选择题直接对答案；简答题按“给分点”判断；编程题优先看并发/语义是否正确，代码风格其次。

## 一、选择题

1. A
2. C

## 二、填空题

### 1. `defer` 输出

- `test1()`：输出 `in defer: x = 7`，返回 `9`
- `test2()`：输出 `in defer: x = 9`，返回 `9`
- `test3()`：先输出 `in defer x as parameter: x = 0`，再输出 `in defer x after return: x = 9`，返回 `9`

速判标准：

- 答对 3 个函数结果给满分
- 说明出“`defer` 实参在注册时求值、闭包取执行时最新值、具名返回值先赋值再执行 `defer`”可视为完全理解

### 2. `for range` 变量取地址

- Go 1.21 及旧语义：通常输出 7 行 `7`
- Go 1.22 及新语义：输出 `1 2 3 4 5 6 7`

速判标准：

- 明确指出“版本差异”即可给主要分
- 能解释旧语义复用循环变量、新语义每轮独立变量，可给满分

## 三、简答题

### 1. `:=` 的作用域规则与陷阱

给分点：

- 只能在函数内部使用
- 作用域从声明处开始，到最内层代码块结束
- 多变量短声明左侧至少有一个新变量
- 内层同名变量会发生遮蔽（shadowing）
- 能举出 `err :=` 遮蔽外层 `err` 的例子

速判标准：答出前 4 点中的 3 点且提到遮蔽陷阱，可给满分。

### 2. 无缓冲 channel 与有缓冲 channel 的区别

给分点：

- 无缓冲：发送和接收必须同步配对
- 有缓冲：缓冲区未满可先发，非空可先收
- 阻塞时机不同
- 使用场景不同：无缓冲偏同步，有缓冲偏解耦/削峰/队列
- 两者使用不当都可能死锁

速判标准：答出同步语义、阻塞时机、适用场景这 3 点即可给主要分。

## 四、编程题

### 1. 生产者-消费者

关键给分点：

- 生产者发送 `1..5`
- 发送结束后正确关闭 channel
- 消费者持续接收并打印
- 主协程等待任务结束再退出
- 不依赖纯 `time.Sleep` 作为完成判定

参考实现：

```go
package main

import (
	"fmt"
	"sync"
)

func producer(ch chan<- int) {
	defer close(ch)
	for i := 1; i <= 5; i++ {
		ch <- i
	}
}

func consumer(ch <-chan int, wg *sync.WaitGroup) {
	defer wg.Done()
	for v := range ch {
		fmt.Println(v)
	}
}

func main() {
	ch := make(chan int)
	var wg sync.WaitGroup

	wg.Add(1)
	go consumer(ch, &wg)
	go producer(ch)

	wg.Wait()
}
```

### 2. `SafeCounter`

关键给分点：

- 结构体里有 `map`
- 使用 `sync.RWMutex` 或等价互斥方案
- `Inc` 写时加锁
- `Value` 读时加读锁
- `map` 有初始化

参考实现：

```go
package main

import "sync"

type SafeCounter struct {
	mu sync.RWMutex
	m  map[string]int
}

func NewSafeCounter() *SafeCounter {
	return &SafeCounter{
		m: make(map[string]int),
	}
}

func (c *SafeCounter) Inc(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.m[key]++
}

func (c *SafeCounter) Value(key string) int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.m[key]
}
```
