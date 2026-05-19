### 本文是Flink学习笔记系列的第四篇文章，主要分享Flink系统架构、时间处理、状态与检查点等核心概念，包括API抽象、JobManager与TaskManager、Flink作业运行基本流程、时间戳与Watermark、状态后端等。

### 系统架构

#### Flink API 抽象

Flink给编程人员提供了不同层次的API抽象。

![](https://ask.qcloudimg.com/http-save/6837176/lu49gfqgp.png)

Flink API抽象结构 来源：Flink官网

1.  Flink最底层提供的是有状态的流式计算引擎，流（Stream）、状态（State）和时间（Time）等流式计算概念都在这一层得到了实现。
2.  一般情况下，应用程序不会使用上述底层接口，而是使用Flink提供的核心API：针对有界和无界数据流的DataStream API和针对有界数据集的DataSet API。用户可以使用这两个API进行常用的数据处理：转换（Transformation）、连接（Join）、聚合（Aggregation）、窗口（Window）以及状态（State）。这一层有点像Spark提供的RDD级别的接口。
3.  Table API和SQL是更高级别的抽象。在这一层，数据被转换成了[关系型数据库](https://cloud.tencent.com/product/tencentdb-catalog?from_column=20065&from=20065)式的表格，每个表格拥有一个表模式（Schema），用户可以像操作表格那样操作流式数据，例如可以使用针对结构化数据的`select`、`join`、`group-by`等操作。如果用户熟悉SQL语句、pandas的DataFrame或者Spark的DataFrame，那么可以很快上手Flink的Table API和SQL。很多公司的数据流非常依赖SQL，Flink SQL降低了从其他框架迁移至Flink的成本。

#### Flink数据流图

之前的文章曾提到了流式计算引擎逻辑视角与物理视角。

![](https://ask.qcloudimg.com/http-save/6837176/wsdljsqndq.png)

Flink示例程序与对应逻辑视角 来源：Flink官网

上图的Flink示例程序对一个数据流做简单处理，整个过程包括了输入（Source）、转换（Transformation）和输出（Sink）。程序由多个DataStream API组成，这些API，又被称为算子 （Operator），共同组成了逻辑视角。在实际执行过程中，逻辑视角会被计算引擎翻译成可并行的物理视角。

![](https://ask.qcloudimg.com/http-save/6837176/7li63nv4te.png)

并行物理视角

在实际执行过程中，这些API或者说这些算子是并行地执行的。在大数据领域，当数据量大到超过单台机器处理能力时，就将一份数据切分到多个分区（pattition）上，每个分区分布在一个虚拟机或物理机。从物理视角上看，每个算子是并行的，一个算子有一个或多个算子子任务（Subtask），每个算子子任务只处理一小部分数据，所有算子子任务共同组成了一个算子。根据算子所做的任务不同，算子子任务的个数可能也不同。上图的例子中，map、keyBy等算子下面的\[1\]和\[2\]表示算子子任务分别运行在第一和第二个分区上，子任务个数都是2；只有数据输出的Sink算子个数是1。算子子任务是相互独立的，一个算子子任务有自己的线程，不同算子子任务可能分布在不同的物理机或虚拟机上。

从上图可以看到，算子子任务之间要做数据交换，数据交换主要包括：

-   前向：例如source\[1\]的输出可以直接传递给map\[1\]，不需要跨节点，数据仍然在同一个分区内，以同样的顺序被处理。
-   数据重分配：子任务将数据发送给不同节点上的其他子任务，例如map\[1\]的结果会被keyBy算子重分配到\[1\]或者\[2\]两个节点上，数据的分布会因此发生变化。

#### Flink核心组件

为了实现支持上述并行物理视角，Flink跟其他大数据系统一样，采用了主从（master-worker）架构，运行时主要包括两个进程：

-   JobManager，又被称为master，是一个Flink应用的主节点。
-   TaskManager，又被称为worker，执行计算任务的节点。

如下图所示，一个Flink应用一般含有至少一个JobManager，一个或多个TaskManager。

![](https://ask.qcloudimg.com/http-save/6837176/gpc74dbwo8.jpeg)

Flink架构与作业提交流程

用户编写Flink应用并提交任务的具体流程为：

1.  用户在客户端（Client）编写应用程序代码。程序一般为Java或Scala语言，调用Flink API算子，构建基于逻辑视角的数据流图。代码和相关配置文件被编译打包，被提交到JobManager上，形成一个应用作业（Application）。
2.  JobManager接受到作业后，将逻辑视角的数据流图转化成可并行执行的物理视角数据流图。
3.  JobManager将物理视角数据流图发送给各TaskManager。
4.  TaskManager执行被分配的任务。
5.  TaskManager在执行任务过程中可能会与其他TaskManager交换数据。
6.  TaskManager中的任务启动、运行、性能指标、结束或终止等状态信息会反馈给JobManager。
7.  用户可以使用Flink Web仪表盘来监控提交的作业。

#### 资源与资源隔离

在计算机领域，计算资源一般指CPU、内存、网络和存储资源。基于现代虚拟化技术，我们可以将一台物理机上的计算资源虚拟化成多个虚拟机。本节简单介绍Flink的资源隔离的机制，并不关注资源虚拟化和调度，这些是资源调度器YARN或Mesos所关注的事情。

上一节提到，TaskManager是直接执行具体任务的基本单位，一个TaskManager中的任务可以是某一个算子的子任务，也可以是不同算子的子任务。TaskManager提供一些槽位（Slot），计算任务被分配到这些槽位中执行。

![](https://ask.qcloudimg.com/http-save/6837176/oyui7oicq2.jpeg)

算子、任务与槽位示意图

上图展示了算子、任务以及槽位之间的关系：左侧为一个含有5个算子的逻辑视角数据流图，右侧为在TaskManager上执行的并行物理视角。Flink给这个作业分配2个TaskManager，每个TaskManager有2个槽位，共4个计算槽位。每个槽位都包含A、B、C、D算子子任务。A、B子任务在交换数据时不需要跨槽位，这将降低数据传输资源开销，C、D子任务之间会跨槽位，产生一些数据传输开销。

在实现TaskManager过程中，Flink在一个Java进程（Process）中启动多个线程（Thread）来并行执行这些任务。比起进程，线程的优势在于更轻量化、数据传输开销更小；线程的劣势是隔离性差，某一个任务出现错误可能导致整个TaskManager上的所有计算都崩溃。不过，Flink高度兼容不同的资源调度框架，如YARN、Mesos或Kubernetes，因此，为了有效隔离计算任务，可以给一个Flink任务单独创建一个Flink集群，或者在分配资源时将某台物理机上的所有资源都分配给同一个TaskManager，这样即使该应用出现问题，也不会影响其他应用。

### 时间处理

在上一章中，我们提到流式大数据处理引擎对时间的复杂要求，并解释了Event Time与Processing Time的区别。Event Time是某个数据实际发生的时间，Processing Time是流式系统处理该条数据的时间。从实际发生到系统接收中间这个过程有一些不确定的延迟，使用Processing Time作为时间，会产生不可复现的结果；使用Event Time作为时间，可以得到一致的、可复现的结果。Event Time虽然准确，但也有其弊端：流式系统无法预知某个时间下，是否所有数据均已到达，因此需要使用Watermark机制处理延迟数据。

Flink应用中每个数据记录包含一个时间戳，时间戳的定义跟业务场景有关，但是一般使用事件实际发生的时间，即Event Time。时间戳一般基于Unix时间戳，即以1970-01-01-00:00:00.000为起始点。毫秒精度是事件距离该起点的毫秒总数，微秒精度是事件距离该起点的微秒总数。

#### Watermark

在上一章我们已经提到，Watermark机制假设在某个时间点上，不会有比这个时间点更晚的上报数据。Watermark常被作为一个时间窗口的结束时间。

![](https://ask.qcloudimg.com/http-save/6837176/lbty0mr93l.png)

一个带有watermark的数据流

Flink中的Watermark是被系统插入到数据流的特殊数据。Watermark的时间戳单调递增，且与事件时间戳相关。如上图的数据流所示，方块是事件，三角形是该事件对应的时间戳，圆圈为Watermark。当Flink接受到时间戳值为5的Watermark时，系统假设时间戳小于5的事件均已到达，后续到达的小于5的事件均为延迟数据。Flink处理到最新的Watermark，会开启这个时间窗口的计算，把这个Watermark之前的数据纳入进此次计算，延迟数据则不能被纳入进来，因此这种计算时有一定微小误差的。

#### 生成Watermark

流数据中的事件时间戳与Watermark高度相关，事件时间戳的抽取和Watermark的生成也基本是同时进行的，抽取的过程会遇到下面两种情况：

1.  数据流中已经包含了事件时间戳和Watermark。
2.  使用抽取算子生成事件时间戳和Watermark，这也是实际应用中更为常见的场景。因为后续的计算都依赖时间，抽取算子最好在数据接入后马上使用。具体而言，抽取算子包含两个函数：第一个函数从数据流的事件中抽取时间戳，并将时间戳赋值到事件的元数据上，第二个函数生成Watermark。

Flink有两种方式来生成Watermark：

1.  周期性（Periodic）生成Watermark：Flink每隔一定时间间隔，定期调用Watermark生成函数。这种方式下，Watermark的生成与时间有周期性的关系。
2.  打点式（Punctuated）生成Watermark：数据流中某些带有特殊标记的数据自带了Watermark信息，Flink监控数据流中的每个事件，当接收到带有特殊标记数据时，会触发Watermark的生成。这种方式下，Watermark的生成与时间无关，与何时接收到特殊标记数据有关。

无论是以上那种方式，Flink都会生成Watermark并插入到数据流中。一旦时间戳和Watermark生成后，后续的算子将以Event Time的时间语义来处理这个数据流。Flink把时间处理部分的代码都做了封装，会在内部处理各类时间问题，用户不需要担心延迟数据等任何时间相关问题。因此，Flink用户只需要在数据接入的一开始生成时间戳和Watermark，Flink会负责剩下的事情。

#### 延迟数据

Flink有一些机制专门收集和处理延迟数据。迟到事件在Watermark之后到达，一般处理的方式有三种：

1.  将迟到事件作为错误事件直接丢弃。
2.  将迟到事件收集起来另外再处理。
3.  重新触发计算。

对于第二种方式，用户可以使用Flink提供的`Side Output`机制，将迟到事件放入一个单独的数据流，以便再对其单独处理。

对于第三种方式，用户可以使用Flink提供的`Allowed Lateness`机制，设置一个允许的最大迟到时长，原定的时间窗口关闭后，Flink仍然会保存该窗口的状态，直至超过迟到时长，迟到的事件加上原来的事件一起重新被计算。

### 状态与检查点

#### 状态

在上一章中我们已经提到了状态的概念，流式大数据处理引擎会根据流入数据持续更新状态数据。状态可以是当前所处理事件的位置偏移（Offset）、一个时间窗口内的某种输入数据、或与具体作业有关的自定义变量。

![](https://ask.qcloudimg.com/http-save/6837176/3r4vla0x36.png)

数据流与状态示意图

如上图所示的应用，我们计算一个实时数据流的最大值与最小值，这个作业的状态包括当前处理的位置偏移、已处理过的最大值和最小值等变量信息。

#### Checkpoint

由于分布式大数据系统运行在多台机器上，因此经常会遇到某台机器宕机、网络出现延迟抖动等问题，一旦出现宕机等问题，该机器上的状态以及相应的计算会丢失，因此需要一种恢复机制来应对这些潜在问题。

Flink使用检查点（Checkpoint）技术来做失败恢复。检查点一般是将状态数据生成快照（Snapshot），持久化存储起来，一旦发生意外，Flink主动重启应用，并从最近的快照中恢复，再继续处理新流入数据。

Flink采用的是一种一致性检查点（Consistent Checkpoint）技术，它可以将分布在多台机器上的所有状态都记录下来，并提供了Exactly-Once的投递保障，其背后是使用了Chandy-Lamport算法，将本地的状态[数据存储](https://cloud.tencent.com/product/cos?from_column=20065&from=20065)到一个存储空间上，并在故障恢复时在多台机器上恢复当前状态。

#### 状态后端

Flink提供了3种存储状态的方式：

1.  内存
2.  文件系统
3.  RocksDB

这三种存储方式又被称为状态后端（State Backend）。

###### **内存**

使用这种方式，Flink会将状态维护在Java堆上。众所周知，内存的访问读写速度最快；其缺点也显而易见，单台机器的内存空间有限，不适合存储大数据量的状态信息。一般在本地开发调试时或者状态非常小的应用场景下使用内存这种方式。

如不做特殊配置，Flink默认使用内存作为Backend。

###### **文件系统**

文件系统包括：

1.  本地文件系统
2.  [分布式文件系统](https://cloud.tencent.com/product/chdfs?from_column=20065&from=20065)，如HDFS、S3。

当选择使用文件系统作为后端时，正在计算的数据会被暂存在TaskManager的内存中。Checkpoint时，此后端会将状态快照写入配置的文件系统中，同时会在JobManager的内存中或者在 Zookeeper 中（高可用情况）存储极少的元数据。

文件系统后端适用于处理大状态，长窗口，或大键值状态的任务。

###### **RocksDB**

RocksDB是一种嵌入式键值数据库，由Facebook开发。使用RocksDB作为后端时，Flink会将实时处理中的数据使用RocksDB存储在本地磁盘上。Checkpoint时，整个RocksDB数据库会被存储到配置的文件系统中，同时Flink会将极少的元数据存储在JobManager的内存中，或者在Zookeeper中（高可用情况）。

RocksDB支持增量Checkpoint，即只对修改的数据做备份，因此非常适合超大状态的场景。

#### Savepoint

在容错上，除了Checkpoint，Flink还提供了Savepoint机制。从名称和实现上，这两个机制都极其相似，甚至Savepoint机制会使用Checkpoint机制的数据，但实际上，这两个机制的定位不同。

![](https://ask.qcloudimg.com/http-save/6837176/2r97rxd52m.jpeg)

Checkpoint 与 Savepoint

Checkpoint是Flink定时触发并自动执行的容错恢复机制，以应对各种意外情况；Savepoint是一种特殊的Checkpoint，它需要编程人员手动介入。比如，用户更新某个应用的代码，需要先停掉该应用并重启，这时就需要使用Savepoint。

### 小结

本文简述了Flink的一些核心概念，包括系统架构、时间处理、状态与检查点。用户可以通过本文了解Flink的基本运行方式。

本文参与 [腾讯云自媒体同步曝光计划](https://cloud.tencent.com/developer/support-plan)，分享自微信公众号。

原始发表：2019-10-12，如有侵权请联系 [cloudcommunity@tencent.com](mailto:cloudcommunity@tencent.com) 删除