# SQL题目-快速批阅版

对应题面：[SQL题目.md](/D:/code/cxGo/docs/笔试/SQL题目.md)

批阅建议：以下以 MySQL 8+ 写法为准；只要候选答案满足题意、能处理并列和边界条件，可按等价写法给分。

## 1. 每个部门第二高薪

标准答案：

```sql
select emp_name, dept_id, salary
from (
    select emp_name,
           dept_id,
           salary,
           dense_rank() over(partition by dept_id order by salary desc) as rk
    from employee
) t
where rk = 2;
```

判分点：必须是“第二种薪资”，并列都返回；部门不足 2 种薪资不返回。

## 2. 平均分与不及格陷阱

标准答案：

```sql
select student_name
from score
group by student_name
having count(distinct course_name) >= 3
   and avg(score) > 80
   and min(score) >= 60;
```

判分点：至少 3 门、平均分大于 80、没有任何一门低于 60。

## 3. 连续 3 天登录用户

标准答案：

```sql
select distinct user_id
from (
    select user_id,
           login_date,
           date_sub(login_date, interval rn day) as grp
    from (
        select user_id,
               login_date,
               row_number() over(partition by user_id order by login_date) as rn
        from (
            select distinct user_id, date(login_time) as login_date
            from user_login
        ) t1
    ) t2
) t3
group by user_id, grp
having count(*) >= 3;
```

判分点：必须先按天去重，再判断连续 3 天，不能把同一天多次登录误算成连续。

## 4. 注册满 30 天但从未下单用户

标准答案：

```sql
select u.user_id, u.user_name
from user_info u
where u.register_time < current_date - interval 30 day
  and not exists (
      select 1
      from order_info o
      where o.user_id = u.user_id
  );
```

判分点：必须同时满足“注册满 30 天”“从未下单”；`NOT EXISTS`、左连接反查都可。

## 5. 互相关注的用户对

标准答案：

```sql
select a.user_id as user_a, a.follow_user_id as user_b
from user_follow a
join user_follow b
  on a.user_id = b.follow_user_id
 and a.follow_user_id = b.user_id
where a.user_id < a.follow_user_id;
```

判分点：自己关注自己不算；每对只返回一次；结果需小 ID 在前。

## 6. 薪资高于直属经理的员工

标准答案：

```sql
select e.emp_name
from employee e
join employee m
  on e.manager_id = m.emp_id
where e.salary > m.salary;
```

判分点：必须是直属经理比较，不是和部门均值或最高值比较。

## 7. 每个部门工资前三高员工

标准答案：

```sql
select emp_name, dept_id, salary
from (
    select emp_name,
           dept_id,
           salary,
           dense_rank() over(partition by dept_id order by salary desc) as rk
    from employee
) t
where rk <= 3;
```

判分点：这里是前三种薪资，不是前三条记录；第三高并列都返回。

## 8. 每个用户最新一笔订单

标准答案：

```sql
select user_id, order_id, amount, create_time
from (
    select user_id,
           order_id,
           amount,
           create_time,
           dense_rank() over(partition by user_id order by create_time desc) as rk
    from order_info
) t
where rk = 1;
```

判分点：同一用户最新时间并列时要全部返回；不能依赖 `order_id` 大小判断新旧。

## 9. 删除重复数据只保留最小 ID

标准答案：

```sql
delete e1
from user_email e1
join user_email e2
  on e1.email = e2.email
 and e1.id > e2.id;
```

判分点：删除重复行但保留每个邮箱最小 ID 那条；若写成子查询删除，逻辑正确也可给满分。
