# SQL 题目

## 1. 每个部门第二高薪

表：`employee(emp_id, emp_name, dept_id, salary)`

题目：查询每个部门第二高薪的员工姓名、部门 ID、薪资。

要求：

1. 第二高薪并列时全部返回
2. 部门不足 2 个不同薪资时不返回

## 2. 平均分与不及格陷阱

表：`score(student_name, course_name, score)`

题目：查询满足以下条件的学生姓名：

1. 至少选修 3 门课程
2. 平均分大于 80 分
3. 不存在任何一门成绩低于 60 分

## 3. 连续 3 天登录用户

表：`user_login(id, user_id, login_time)`

题目：查询至少存在一次连续 3 天登录的用户 ID。

## 4. 注册满 30 天但从未下单用户

表：

- `user_info(user_id, user_name, register_time)`
- `order_info(order_id, user_id, order_time)`

题目：查询注册满 30 天但从未下单的用户 ID 和用户名。

## 5. 互相关注的用户对

表：`user_follow(user_id, follow_user_id)`

题目：查询所有互相关注的用户对。

要求：

1. 每对用户只返回一次
2. 小 ID 在前，大 ID 在后
3. 自己关注自己不算

## 6. 薪资高于直属经理的员工

表：`employee(emp_id, emp_name, salary, manager_id)`

题目：查询薪资高于直属经理的员工姓名。

## 7. 每个部门工资前三高员工

表：`employee(emp_id, emp_name, dept_id, salary)`

题目：查询每个部门工资前三高的员工姓名、部门 ID、薪资。

要求：

1. 第三高薪并列时全部返回
2. 这里的“前三高”指前三种薪资，不是前三条记录

## 8. 每个用户最新一笔订单

表：`order_info(order_id, user_id, amount, create_time)`

题目：查询每个用户最新一笔订单的 `user_id`、`order_id`、`amount`、`create_time`。

要求：

1. 最新时间并列时全部返回
2. 不能假设 `order_id` 越大，下单时间越晚

## 9. 删除重复数据只保留最小 ID

表：`user_email(id, email)`

题目：删除重复邮箱数据，只保留每个邮箱中 ID 最小的那条记录。
