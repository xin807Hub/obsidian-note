# Go 语言中级面试题 - 经典踩坑篇

说明：
- 本文只保留题目、代码片段和追问，用于面试前快速过题。
- 参考答案已单独拆分到 `Go语言面试题-解答.md`。

## 一、切片与数组

### 切片的 append 问题
```go
func main() {
    s := make([]int, 3, 5)

    appendSlice(s)

    fmt.Println(s)
}

func appendSlice(arr []int) {
    arr = append(arr,888)
}


请问最后输出的是append之后的吗？
```

### 1. 切片底层原理与扩容

以下代码的输出是什么？请解释原因。

```go
func main() {
    s := make([]int, 3, 5)
    s[0] = 1
    s[1] = 2
    s[2] = 3

    s = append(s, 4)
    s[0] = 100

    fmt.Println(s)
}
```

追问：
- 切片扩容时新容量的计算规则是什么？
- 扩容后底层数组是原数组的拷贝吗？

### 2. 切片 append 陷阱

请指出下面代码的问题：

```go
func main() {
    s := []int{1, 2, 3}
    s = append(s, 4, 5)

    // 请问 s 和 s[:3] 共享底层数组吗？
    fmt.Println(s[:3])
}
```

### 3. 数组作为函数参数

下面两个函数的区别是什么？

```go
func modifyArray(a [3]int) {
    a[0] = 100
}

func modifySlice(s []int) {
    s[0] = 100
}

func main() {
    arr := [3]int{1, 2, 3}
    slice := []int{1, 2, 3}

    modifyArray(arr)
    modifySlice(slice)

    fmt.Println(arr, slice)
}
```

### 4. 切片内存泄漏

以下代码会造成内存泄漏吗？请说明原因。

```go
func main() {
    slice := make([]int, 0, 1000)
    for i := 0; i < 1000; i++ {
        slice = append(slice, i)
    }

    // 只使用前 10 个元素
    process(slice[:10])

    // 请问此时 slice 的底层数组有多大？
    fmt.Println(cap(slice))
}

func process(s []int) {
    // 业务处理
}
```

## 二、For 循环与闭包

### 5. Go for 循环变量捕获

请问下面的代码输出什么？如何修复？

```go
func main() {
    var funcs []func()

    for i := 0; i < 3; i++ {
        funcs = append(funcs, func() {
            fmt.Println(i)
        })
    }

    for _, f := range funcs {
        f()
    }
}
```

追问：
- 这与 Python、JavaScript 的闭包问题有何不同？
- Go 1.22 有什么变化？

### 6. for + goroutine 经典问题

下面代码有什么问题？如何正确修改？

```go
func main() {
    urls := []string{"a.com", "b.com", "c.com"}

    for _, url := range urls {
        go func() {
            fmt.Println(url)
        }()
    }

    time.Sleep(time.Second)
}
```

## 三、Map 与并发

### 7. Map 并发读写

下面的代码有什么问题？如何检测和解决？

```go
func main() {
    m := make(map[string]int)

    go func() {
        for {
            m["key"] = 1
        }
    }()

    go func() {
        for {
            _ = m["key"]
        }
    }()

    time.Sleep(time.Second)
}
```

### 8. Map 遍历顺序随机

为什么 Map 的遍历顺序是随机的？这会带来什么问题？如何解决？

```go
func main() {
    m := map[string]int{
        "a": 1,
        "b": 2,
        "c": 3,
    }

    for i := 0; i < 5; i++ {
        for k, v := range m {
            fmt.Println(k, v)
        }
    }
}
```

### 9. Map 值类型赋值陷阱

请分析下面代码的问题：

```go
type User struct {
    Name string
    Age  int
}

func main() {
    m := make(map[string]User)

    m["tom"] = User{Name: "Tom", Age: 20}

    user := m["tom"]
    user.Age = 30

    fmt.Println(m["tom"].Age)  // 输出什么？
}
```

## 四、Defer 与 Panic

### 10. defer 执行顺序与参数求值

下面代码的输出是什么？

```go
func main() {
    i := 0

    defer fmt.Println("A:", i)
    i++

    defer func() {
        fmt.Println("B:", i)
    }()
    i++

    defer func(i int) {
        fmt.Println("C:", i)
    }(i)
    i++

    panic("error")
}
```

### 11. defer 资源泄漏

以下代码会造成资源泄漏吗？

```go
func readFile(path string) ([]byte, error) {
    file, err := os.Open(path)
    if err != nil {
        return nil, err
    }

    defer file.Close()

    return io.ReadAll(file)
}

func process() error {
    file, err := os.Open("/tmp/test.txt")
    if err != nil {
        return err
    }

    // 如果这里 return 了，file 会关闭吗？
    return nil
}
```

## 五、GORM 踩坑

### 12. GORM 预加载与 N+1 问题

请分析以下代码的 N+1 问题，并给出优化方案：

```go
type User struct {
    ID    uint
    Name  string
    Posts []Post
}

type Post struct {
    ID     uint
    Title  string
    UserID uint
}

func main() {
    var users []User
    db.Find(&users)

    for _, user := range users {
        fmt.Println(user.Name)
        for _, post := range user.Posts {
            fmt.Println(" -", post.Title)
        }
    }
}
```

追问：
- 什么是预加载（Preload）？
- 如何使用 `Join` 优化？
- GORM 的 `Select` 和 `Omit` 有什么用？

### 13. GORM 事务未生效

以下代码的事务会生效吗？为什么？

```go
func CreateUserAndOrder(db *gorm.DB, user User, order Order) error {
    err := db.Transaction(func(tx *gorm.DB) error {
        if err := tx.Create(&user).Error; err != nil {
            return err
        }

        order.UserID = user.ID
        if err := tx.Create(&order).Error; err != nil {
            return err
        }

        return nil
    })

    return err
}
```

追问：
- GORM 事务回滚后，主键会回滚吗？
- Save 和 Create 有什么区别？

### 14. GORM 软删除与查询

用户被软删除后，以下查询还能查到吗？为什么？

```go
type User struct {
    ID   uint
    Name string
    DeletedAt gorm.DeletedAt `gorm:"index"`
}

func main() {
    var user User
    db.First(&user, 1)  // 能查到已删除的用户吗？

    db.Unscoped().First(&user, 1)  // 这个呢？
}
```

### 15. GORM 关联关系更新

如何正确更新 User 和其关联的 Profile？

```go
type User struct {
    ID      uint
    Name    string
    Profile Profile
}

type Profile struct {
    ID     uint
    UserID uint
    Bio    string
}

// 下面的代码能正确更新吗？
func UpdateUser(db *gorm.DB, user User) error {
    return db.Save(&user).Error
}
```

## 六、其他经典踩坑

### 16. Goroutine 泄露

以下代码会造成 goroutine 泄露吗？

```go
func main() {
    ch := make(chan int)

    go func() {
        for i := 0; i < 10; i++ {
            ch <- i
        }
        // 没有关闭 channel
    }()

    time.Sleep(time.Second)
    fmt.Println("done")
}
```

### 17. JSON 序列化零值问题

为什么 struct 序列化后某些字段丢失了？

```go
type User struct {
    ID      int    `json:"id"`
    Name    string `json:"name"`
    Age     int    `json:"age,omitempty"`
    Balance int    `json:"-"`
}

func main() {
    user := User{ID: 1, Name: "Tom", Age: 0}
    data, _ := json.Marshal(user)
    fmt.Println(string(data))
}
```

### 18. Context 取消与超时

下面的代码有什么问题？

```go
func main() {
    ctx, cancel := context.WithTimeout(context.Background(), time.Second)
    defer cancel()

    go func() {
        time.Sleep(2 * time.Second)
        fmt.Println("goroutine done")
    }()

    select {
    case <-ctx.Done():
        fmt.Println("timeout")
    }
}
```

### 19. 接口 nil 判断

下面的代码输出什么？

```go
func getError() error {
    var err *MyError = nil
    return err
}

type MyError struct {
    msg string
}

func (e *MyError) Error() string {
    return e.msg
}

func main() {
    err := getError()
    fmt.Println(err == nil)        // 输出什么？
    fmt.Println(err)               // 输出什么？
}
```

### 20. 切片与数组转换

下面两种方式有什么性能差异？

```go
// 方式1
arr := [3]int{1, 2, 3}
s := arr[:]

// 方式2
s := []int{1, 2, 3}
```

## 七、Gin 框架踩坑

### 24. Gin 路由匹配与参数获取

下面代码的问题是什么？

```go
func main() {
    r := gin.Default()

    r.GET("/user/:name", func(c *gin.Context) {
        name := c.Param("name")
        c.JSON(200, gin.H{"name": name})
    })

    // 请问 /user/ 和 /user/:name 哪个先注册？
    r.GET("/user/", func(c *gin.Context) {
        c.JSON(200, gin.H{"msg": "list"})
    })

    r.Run(":8080")
}
```

追问：
- Gin 的路由是如何匹配的？
- `*` 和 `:` 有什么区别？

### 25. Gin 中间件执行顺序

以下代码中，MiddlewareA、MiddlewareB、Handler 的执行顺序是什么？

```go
func main() {
    r := gin.New()

    r.Use(MiddlewareA())

    r.GET("/test", MiddlewareB(), func(c *gin.Context) {
        c.JSON(200, gin.H{"msg": "test"})
    })

    r.Run(":8080")
}

func MiddlewareA() gin.HandlerFunc {
    return func(c *gin.Context) {
        fmt.Println("A before")
        c.Next()
        fmt.Println("A after")
    }
}

func MiddlewareB() gin.HandlerFunc {
    return func(c *gin.Context) {
        fmt.Println("B before")
        c.Next()
        fmt.Println("B after")
    }
}
```

### 26. Gin 上下文并发安全

以下代码有什么问题？

```go
func Handler(c *gin.Context) {
    go func() {
        time.Sleep(time.Second)
        c.JSON(200, gin.H{"msg": "done"})  // 这里有什么问题？
    }()
    c.JSON(200, gin.H{"msg": "ok"})
}
```

### 27. Gin 参数绑定与默认值

以下代码能正确获取参数吗？

```go
type User struct {
    Name string `form:"name" json:"name"`
    Age  int    `form:"age" json:"age"`
}

func main() {
    r := gin.Default()

    r.GET("/user", func(c *gin.Context) {
        var user User
        c.ShouldBind(&user)

        // 如果不传 age，user.Age 是多少？
        fmt.Println(user)
        c.JSON(200, user)
    })

    r.Run(":8080")
}
```

追问：
- `Bind`、`ShouldBind`、`ShouldBindJSON` 有什么区别？
- 如何设置默认值？

### 28. Gin 文件上传与大小限制

上传大文件时 gin.Default() 有什么限制？如何修改？

```go
func main() {
    r := gin.Default()

    r.POST("/upload", func(c *gin.Context) {
        file, err := c.FormFile("file")
        if err != nil {
            c.JSON(500, gin.H{"error": err.Error()})
            return
        }
        c.SaveUploadedFile(file, "./"+file.Filename)
        c.JSON(200, gin.H{"msg": "ok"})
    })

    r.Run(":8080")
}
```

### 29. Gin 优雅关闭

如何在 Gin 中实现优雅关闭（Graceful Shutdown）？

```go
func main() {
    r := gin.Default()

    srv := &http.Server{
        Addr:    ":8080",
        Handler: r,
    }

    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Server error: %v", err)
        }
    }()

    // 如何优雅关闭？
}
```

## 八、实战场景

### 30. 高并发计数器实现

请用 Go 实现一个高性能的计数器，支持：
- Inc() 加一
- Count() 获取当前值
- 1000 个 goroutine 并发调用

你会如何实现？为什么？

### 31. 限流器实现

请实现一个令牌桶限流器，要求：
- 每秒生成 N 个令牌
- 桶最多缓存 M 个令牌
- 支持并发安全

### 32. 生产者消费者模型

实现一个生产者-消费者模型：
- 多个生产者并发写入数据
- 多个消费者并发读取数据
- 使用 channel 实现
- 考虑优雅关闭

## 面试建议

### 考察重点
1. **语言底层理解** - 切片、Map、Channel 的底层实现
2. **并发安全意识** - 何时需要加锁，何时是线程安全的
3. **问题排查能力** - 能否快速定位问题
4. **最佳实践** - 是否知道常见的坑和规避方法

### 评分标准
1. **能否准确回答输出** - 验证对语言的理解深度
2. **能否解释原因** - 不仅知其然，还要知其所以然
3. **能否给出正确方案** - 知道问题后能否写出正确代码
4. **追问应对** - 深入追问源码实现、Go 版本差异等
