# Go 笔试题目

说明：保留原题意，补充参考答案与简要解析；涉及 Go 版本差异的题目，按不同版本分别说明。

## 一、选择题

### 1. 下面程序输出结果是？

```go
func sliceA(a []int) {
	a = append(a, 3)
}

func sliceC(a []int) {
	a[3] = 99
}

func Test_slice_t(t *testing.T) {
	a := []int{0, 1, 2, 0}

	sliceA(a)
	sliceC(a)

	fmt.Println(a)
}
```

A. `[0 1 2 99]`  
B. `[0 1 2 0]`  
C. `[0 1 2 99 3]`

参考答案：A

解析：`slice(a)` 会直接修改底层数组，因此 `a[3]` 被改成 `99`。`sliceA(a)` 内部即使执行了 `append`，也只是修改了函数内局部切片变量的切片头，没有把新切片返回给调用方，所以调用方最终看到的还是 `[0 1 2 99]`。

### 2. 以下代码输出什么？

```go
package main

import (
	"fmt"
	"time"
)

func main() {
	ch1 := make(chan int)
	go fmt.Println(<-ch1)
	ch1 <- 5
	time.Sleep(1 * time.Second)
}
```

A. `5`  
B. 不能编译  
C. 运行时死锁

参考答案：C

解析：代码可以正常编译，但会在运行时死锁。关键点在于 `go fmt.Println(<-ch1)` 并不是“先启动 goroutine，再在 goroutine 里执行 `<-ch1>`”，而是会先计算函数调用参数，再启动 goroutine。也就是说，它等价于先执行 `tmp := <-ch1`，这里会因为 `ch1` 是无缓冲 channel 而立即阻塞，导致后面的 `ch1 <- 5` 永远执行不到，所以最终死锁。只有把接收操作放进匿名函数里，例如 `go func() { fmt.Println(<-ch1) }()`，`<-ch1` 才会在新的 goroutine 中执行。

## 二、填空题

### 1. 以下代码输出什么？

```go
func test1() (x int) {
	x = 7
	defer fmt.Printf("in defer: x = %d\n", x)
	return 9
}

func test2() (x int) {
	defer func() {
		fmt.Printf("in defer: x = %d\n", x)
	}()

	x = 7
	return 9
}

func test3() (x int) {
	defer func(n int) {
		fmt.Printf("in defer x as parameter: x = %d\n", n)
		fmt.Printf("in defer x after return: x = %d\n", x)
	}(x)

	x = 7
	return 9
}
```

参考答案：

- `test1()` 输出 `in defer: x = 7`，返回值是 `9`
- `test2()` 输出 `in defer: x = 9`，返回值是 `9`
- `test3()` 先输出 `in defer x as parameter: x = 0`，再输出 `in defer x after return: x = 9`，返回值是 `9`

解析：`defer` 调用的参数在 `defer` 语句执行时就会求值，但闭包里直接引用外部变量时，读取的是真正执行 `defer` 时该变量的最新值。具名返回值在执行 `return 9` 时会先被赋值为 `9`，然后再执行延迟函数。

### 2. 以下代码输出什么？

![img_4.png](img_4.png)

参考答案：

- Go 1.21 及以前，或模块仍按旧循环变量语义编译时：通常会输出 7 行 `7`
- Go 1.22 及以后，且模块启用了新循环变量语义时：会依次输出 `1 2 3 4 5 6 7`

解析：题目考察的是 `for range` 循环变量取地址的版本差异。旧语义下，循环变量 `node` 在每轮复用，`&node` 得到的往往是同一个地址，所以最后打印出来都是最后一次迭代的值。新语义下，每次迭代都有独立的循环变量，因此每个指针都能对应到各自那一轮的值。

## 三、简答题

### 1. 请解释 Go 语言中短变量声明 `:=` 的作用域规则，并举例说明可能引起的陷阱。

参考答案：

1. `:=` 只能在函数内部使用，不能用于包级变量声明。
2. 变量作用域从声明语句之后开始，持续到所在的最内层代码块结束。
3. 多变量短声明时，左侧至少要有一个“新变量”，否则会报错。
4. 如果左侧某些变量在当前代码块中已经存在，那么这些变量会被重新赋值；如果是在内层代码块中重新声明同名变量，则会发生变量遮蔽。

常见陷阱示例：

```go
func demo() error {
	var err error

	if true {
		err := doSomething()
		if err != nil {
			return err
		}
	}

	return err
}
```

解析：`if` 代码块里的 `err :=` 声明了一个新的局部变量，它遮蔽了外层的 `err`。这种写法容易让人误以为操作的是同一个变量，实际不是。

### 2. 说明无缓冲 channel 和有缓冲 channel 的主要区别。

参考答案：

1. 无缓冲 channel 的发送和接收必须同时准备好，发送方和接收方会直接同步配对。
2. 有缓冲 channel 内部有队列，只要缓冲区未满，发送方就可以先放入数据而不立即阻塞；只要缓冲区非空，接收方就可以直接取数据。
3. 无缓冲 channel 更强调协程之间的同步；有缓冲 channel 更适合做解耦、削峰或有限队列。
4. 无缓冲 channel 在没有接收者时发送会阻塞；有缓冲 channel 在缓冲区满时发送才会阻塞。
5. 两者如果使用不当都可能导致死锁，只是触发条件不同。

## 四、编程题

### 1. 使用 goroutine 和 channel 实现一个简单的生产者-消费者模型：

- 生产者生产 5 个整数（`1,2,3,4,5`）并发送到 channel
- 消费者从 channel 接收并打印每个数字
- 主函数等待完成后退出

参考答案：

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

解析：生产者负责发送数据并在结束后关闭 channel；消费者通过 `range ch` 持续接收直到 channel 关闭；主协程通过 `sync.WaitGroup` 等待消费者结束，而不是使用不可靠的 `time.Sleep`。

### 2. 编写一个 `SafeCounter` 结构体，内部包含一个 `map` 和一个 `sync.RWMutex`，提供 `Inc(key string)` 和 `Value(key string) int` 方法，并保证并发安全。

参考答案：

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

解析：写操作需要加写锁 `Lock`，读操作使用读锁 `RLock`。`map` 本身不是并发安全的，必须通过互斥锁保护。
