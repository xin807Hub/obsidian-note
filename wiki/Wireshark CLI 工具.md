# Wireshark CLI 工具

## 一句话总结

`capinfos` 和 `editcap` 不是 Linux 自带命令，属于 **Wireshark 命令行工具集**（Wireshark / tshark 安装后附带），用于 pcap/pcapng 抓包文件的查看与处理。

## 工具速查

| 命令 | 作用 |
| --- | --- |
| `capinfos` | 查看抓包文件信息（包数、时长、大小等） |
| `editcap` | 裁剪、拆分、转换抓包文件 |
| `tshark` | 命令行版 Wireshark，可过滤、解析、导出协议字段 |
| `mergecap` | 合并多个抓包文件 |

## capinfos — 查看抓包文件信息

统计包数量：

```bash
capinfos -c 1_203620413.pcapng
```

输出示例：

```text
Number of packets: 141 k
```

### 常用参数

| 参数 | 作用 |
| --- | --- |
| `-c` | 统计包数量 |
| `-t` | 显示起止时间 |
| `-d` | 显示时长 |
| `-s` | 显示文件大小 |
| `-a` | 显示所有信息 |

## editcap — 裁剪与拆分抓包文件

### 按包序号提取范围

```bash
editcap -r 1_203620413.pcapng 50M_new.pcapng 1-68085
```

- 从原始文件提取第 1 到 68085 个包
- `-r` 表示**保留**指定范围内的包
- 生成新文件 `50M_new.pcapng`

### 按文件大小拆分

```bash
editcap -c 10000 input.pcapng output_split.pcapng
```

`-c` 指定每个输出文件最多包含的包数。

## 确认是否已安装

```bash
which capinfos
which editcap
capinfos -v
```

### 查看所属包

**CentOS / openEuler / RHEL：**

```bash
rpm -qf $(which capinfos)
```

**Ubuntu / Debian：**

```bash
dpkg -S $(which capinfos)
```

## 安装方法

### 先确认系统

```bash
cat /etc/os-release
```

### CentOS / RHEL / openEuler

```bash
yum install -y wireshark-cli
```

或用 `dnf`：

```bash
dnf install -y wireshark-cli
```

如果找不到包，先搜索实际包名：

```bash
yum search wireshark
```

### Ubuntu / Debian

```bash
apt update
apt install -y tshark
```

或：

```bash
apt install -y wireshark-common
```

## 离线安装

适用于服务器无法联网的场景。

### CentOS / openEuler 类

在**联网、同版本系统**机器上：

```bash
yum install -y yum-utils
mkdir -p /tmp/wireshark-rpms
cd /tmp/wireshark-rpms
yumdownloader --resolve wireshark-cli
```

将 `/tmp/wireshark-rpms` 目录拷贝到离线服务器后执行：

```bash
cd /tmp/wireshark-rpms
rpm -Uvh *.rpm
```

## 典型工作流

```bash
# 1. 查看总包数
capinfos -c 1_203620413.pcapng

# 2. 按包序号截取一部分
editcap -r 1_203620413.pcapng 50M_new.pcapng 1-68085

# 3. 验证新文件
capinfos 50M_new.pcapng
```

## 相关页面

- [[DPI]]
- [[Linux 常用命令备注]]

