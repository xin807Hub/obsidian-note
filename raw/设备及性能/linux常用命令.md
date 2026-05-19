linux常用命令

检查端口服务是否可用：

nc -zv 192.168.37.162 8088

（z 参数告诉netcat使用0 IO,连接成功后立即关闭连接， 不进行数据交换.）

curl：

post：curl -X POST "http://172.16.1.202:8005/api/pcapCluster"  -H "Content-Type:application/json" -d "[\"1665888970_1:MGLYL2lZ9/+EbnVYhcJlvnlkNE4=\"]"

linux 查看内存使用的前十名

ps aux|head -1;ps aux|grep -v PID|sort -rn -k +4|head #查看内存使用前十名 (RSS:进程实际使用的物理内存单位KB)

命令详解

一、ps + grep + head
ps aux|head -1;ps aux|grep -v PID

要查看进程肯定离不开ps命令，由于系统中的进程会比较多，通过ps 会结合grep一起使用；
使用grep过滤时常常会把ps命令的第1行也过滤掉，这里的一个技巧是使用两次ps，第一个ps + head用于展示头信息; 第二个ps + grep用于过滤不需要的信息
二、 sort + head
sort -rn -k +4

要排序自然离不开sort，下面介绍一下sort的常用方法：
-n 按照数字排序，默认按照ASCII排序
-r 按照逆序排序，默认升序
-u 排序去重
-t 指定分割分割符，默认按照空格分割
-k 当一行可以被分割符分割成多个字段时，可以指定按照第几个字段进行排序
head命令比较简单，默认显示10行。
-n 指定行数
-c 指定字节数



查看网卡状态：

sar -n DEV 1 100

1: 每一秒统计一次

100：统计100次（可以省略）



查看磁盘io：

iostat -mx 1 100







三、测试硬盘读写



测试磁盘写能力：

time dd if=/dev/zero of=/testw.dbf bs=4k count=100000

因为/dev/zero是一个伪设备，它只产生空字符流，对它不会产生IO，所以，IO都会集中在of文件中，of文件只用于写，所以这个命令相当于测试磁盘的写能力。命令结尾添加oflag=direct将跳过内存缓存，添加oflag=sync将跳过hdd缓存。


测试磁盘读能力：

time dd if=/dev/sdb of=/dev/null bs=4k

因为/dev/sdb是一个物理分区，对它的读取会产生IO，/dev/null是伪设备，相当于黑洞，of到该设备不会产生IO，所以，这个命令的IO只发生在/dev/sdb上，也相当于测试磁盘的读能力。（Ctrl+c终止测试）


测试同时读写能力：

time dd if=/dev/sdb of=/testrw.dbf bs=4k
在这个命令下，一个是物理分区，一个是实际的文件，对它们的读写都会产生IO（对/dev/sdb是读，对/testrw.dbf是写），假设它们都在一个磁盘中，这个命令就相当于测试磁盘的同时读写能力。




四、查看device与磁盘分区关系：

ll /dev/mapper/







五、查看raid卡以及物理磁盘状况

/opt/MegaRAID/storcli/storcli64 /c0  show all





