+++
date = '2024-12-04T19:01:15+08:00'
lastmod = '2024-12-04T19:01:15+08:00'
draft = false
title = '分布式事务一致性业界方案及实践经验总结'
tags = ['Thinking']
categories = ['Engineering']
series = []
+++
日常需求经常需要用到分布式事务一致性保障，踩坑摸索中积累了一些经验，结合各种内外部资料，统一做一次梳理，并在最后附上一些实践经验

举例一个业务场景：银行账户 A 转账给银行账户 B 100 元 引入问题和要求：
- A-100 和 B+100 都成功，或都失败
- 转账前 A+B 总额 == 转账后 A+B 总额
- 同一段时间多笔转账间尽量能够并行且不互相影响
- 转账完成后数据永久保存不丢失

## 1. 本地（单机）事务场景
假如我们的业务系统不复杂，可以在一个数据库、一个服务内对数据进行修改，完成转账，那么，我们可以利用数据库事务，保证转账业务的正确完成。现有的关系型数据库在这方面已经非常完善了
在单机数据库场景下，事务保证 ACID 要求
> 摘自维基百科： 原子性（Atomicity）：一个事务（transaction）中的所有操作，或者全部完成，或者全部不完成，不会结束在中间某个环节。事务在执行过程中发生错误，会被回滚（Rollback）到事务开始前的状态，就像这个事务从来没有执行过一样。即，事务不可分割、不可约简。[1] 一致性（Consistency）：在事务开始之前和事务结束以后，数据库的完整性没有被破坏。这表示写入的资料必须完全符合所有的预设约束、触发器、级联回滚等。[1] 事务隔离（Isolation）：数据库允许多个并发事务同时对其数据进行读写和修改的能力，隔离性可以防止多个事务并发执行时由于交叉执行而导致数据的不一致。事务隔离分为不同级别，包括未提交读（Read uncommitted）、提交读（read committed）、可重复读（repeatable read）和串行化（Serializable）。[1] 持久性（Durability）：事务处理结束后，对数据的修改就是永久的，即便系统故障也不会丢失。[1]

在常见互联网业务场景下，都是读多写少，所以比较多都是用 MVCC 技术，用版本号和快照的方案实现高并发（Repeatable Read）下的一致性

## 2. 分布式事务
现实情况下，绝大多数的互联网业务都是分布式系统，服务、资源、数据库等都不是单机部署，甚至可能横跨多家公司、运营商。所以在这种场景下，原有的本地事务保证已经无法满足需求

### 2.1 数据库内部分布式事务
一些分布式数据库原生内部支持事务特性，可以大大减少业务方操作事务的复杂性，基本由数据库组件来解决问题 目前常见的支持分布式事务的数据库举例：
- TDSQL（腾讯）
- TBase（腾讯）
- TiDB( PingCAP)
- Spanner( Google)
- OceanBase（阿里巴巴）

这种方案比较适合数据位于同一个数据库组件，只需要能够保证并发操作不会造成数据不一致的业务

### 2.2 更广泛场景下的的异构分布式事务
更多时候，我们的业务流程都比较复杂，比如上网买个女朋友。核心的流程至少有：
1. 下单
2. 支付
3. 扣库存
4. 发货

每个步骤可能都是由不同服务操作，相关的数据存储在不同数据库中。这种情况下，难以有统一的版本号，MVCC 手段无法使用，且目前为止还没有支持跨数据库的严格一致性方案

相对应于本地事务的强 ACID 要求，分布式事务场景下，为了面向高可用、可扩展等要求，一般会进行取舍，降低部分一致性和隔离性的要求，遵循 BASE 理论：
- 基本业务可用（Basic Availability）
- 软状态（Soft state）
- 最终一致（Eventual consistency）

分布式事务中的 ACID 情况：
- 原子性：严格遵循，采用类似 UNDO 的方式实现
- 一致性：完成后的一致性严格遵循；事务中的一致性可适当放宽
- 隔离性：大量事务可以并行
- 持久性：严格遵循

目前业界常见的分布式事务解决方案有
- XA（两阶段提交、三阶段提交）
- TCC
- SAGA
- 本地消息表
- 事务消息
- 最大努力通知
- AT 事务模式

## 3. XA
XA 是由 X/Open 组织提出的分布式事务规范，这个规范主要定义了（全局）事务管理器（TM） 和（局部）资源管理器（RM）之间的接口。本地数据库如 MySQL 对应的是这里的 RM 角色 XA 由一个或多个资源管理器（RM），一个事务管理器（TM）和一个应用程序（ApplicationProgram）组成。这三个角色概念 RM、TM、AP 是经典的角色划分，需要见名知意
目前主流的数据库基本都支持 XA 事务

### 3.1 两阶段提交
顾名思义就是需要分两步提交事务： 第一阶段（prepare）：事务管理器向所有本地资源管理器发起请求，询问是否是 ready 状态，所有参与者都将本事务能否成功的信息反馈发给协调者 第二阶段（commit/rollback）：事务管理器根据所有本地资源管理器的反馈，通知所有本地资源管理器，步调一致地在所有分支上提交或者回滚

{{< image src="https://webp.slightsnow.com/2024/12/8146842de573364db3c64bd162ada3a8.png" caption="202412041918201" height="800" width="550" >}}

优点：
- 简单容易理解，开发较容易

缺点：
- 同步阻塞问题：prepare 阶段锁住了资源，其他参与者需要等前一个参与者释放，并发度低
- 单点问题：事务管理器出现故障，整个系统不可用
- 不一致的可能：commit/rollback 阶段，如果事务管理器只发送了部分 commit 消息，此时如果事务管理宕机（极端情况某些参与者也一起宕机），则难以保证所有参与者一致性正常

不一致的可能，可以引入**超时机制**和**互询机制**来很大程度解决： 对于协调者来说如果在指定时间内没有收到所有参与者的应答，则可以自动退出 WAIT 状态，并向所有参与者发送 rollback 通知。对于参与者来说如果位于 READY 状态，但是在指定时间内没有收到协调者的第二阶段通知，则不能武断地执行 rollback 操作，因为协调者可能发送的是 commit 通知，这个时候执行 rollback 就会导致数据不一致。 此时，我们可以介入互询机制，让参与者 A 去询问其他参与者 B 的执行情况。如果 B 执行了 rollback 或 commit 操作，则 A 可以大胆的与 B 执行相同的操作；如果 B 此时还没有到达 READY 状态，则可以推断出协调者发出的肯定是 rollback 通知；如果 B 同样位于 READY 状态，则 A 可以继续询问另外的参与者。只有当所有的参与者都位于 READY 状态时，此时两阶段提交协议无法处理，将陷入长时间的阻塞状态

### 3.2 三阶段提交
针对两阶段提交存在的问题，三阶段提交协议通过引入一个预询阶段，以及超时策略来减少整个集群的阻塞时间，提升系统性能。三阶段提交的三个阶段分别为：预询（can_commit）、预提交（pre_commit），提交（do_commit）

{{< image src="https://webp.slightsnow.com/2024/12/4db6cf49d9e624b4398b933d65889ae7.png" caption="202412041918254" height="800" width="550" >}}

第一阶段：该阶段协调者会去询问各个参与者是否能够正常执行事务，参与者根据自身情况回复一个预估值，相对于真正的执行事务，这个过程是轻量的，具体步骤如下
1. 协调者向各个参与者发送事务询问通知，询问是否可以执行事务操作，并等待回复
2. 各个参与者依据自身状况回复一个预估值，如果预估自己能够正常执行事务就返回确定信息，并进入预备状态，否则返回否定信息

第二阶段：本阶段协调者会根据第一阶段的询问结果采取相应操作，询问结果主要有 3 种：
1. 所有的参与者都返回确定信息
2. 一个或多个参与者返回否定信息
3. 协调者等待超时

针对第一种情况，协调者会向所有参与者发送事务执行请求：
1. 协调者向所有的事务参与者发送事务执行通知
2. 参与者收到通知后执行事务但不提交
3. 参与者将事务执行情况返回给客户端

**在上述步骤中如果参与者等待超时，以及询问结果的后两种异常情况，则会中断事务，向各个参与者发送 abort 通知，请求退出预备状态**

第三阶段： 如果第二阶段事务未中断，那么本阶段协调者将会依据事务执行返回的结果来决定提交或回滚事务，分为 3 种情况：
1. 所有的参与者都能正常执行事务
2. 一个或多个参与者执行事务失败
3. 协调者等待超时

针对第 1 种情况，协调者向各个参与者发起事务提交请求，具体步骤如下
1. 协调者向所有参与者发送事务 commit 通知
2. 所有参与者在收到通知之后执行 commit 操作，并释放占有的资源
3. 参与者向协调者反馈事务提交结果

针对第 2 和第 3 种情况，协调者认为事务无法成功执行，于是向各个参与者发送事务回滚请求，具体步骤如下
1. 协调者向所有参与者发送事务 rollback 通知
2. 所有参与者在收到通知之后执行 rollback 操作，并释放占有的资源
3. 参与者向协调者反馈事务回滚结果

总结：三阶段提交是两阶段提交的进化方案。但在两阶段提交中，长时间资源阻塞和数据不一致发生的可能性还是比较低的，所以虽然三阶段提交协议相对于两阶段提交协议对于数据强一致性更有保障，但因过于复杂，且效率相对低，两阶段提交在实际中应用更多

## 4. TCC
关于 TCC（Try-Confirm-Cancel）的概念，最早是由 Pat Helland 于 2007 年发表的一篇名为《Life beyond Distributed Transactions:an Apostate’s Opinion》的论文提出。 TCC 事务机制相比于上面介绍的 XA，解决了其几个缺点：
1. 同步阻塞：引入超时，超时后进行补偿，并且不会锁定整个资源，将资源转换为业务逻辑形式，粒度变小
2. 解决了协调者单点，由主业务方发起并完成这个业务活动。业务活动管理器也变成多点，引入集群
3. 数据一致性，有了补偿机制之后，由业务活动管理器控制一致性

TCC 分为三个阶段：
- Try 阶段：尝试执行，完成所有业务检查（一致性），预留必须业务资源（准隔离性）
- Confirm 阶段：确认执行真正执行业务，不做任何业务检查，只使用 Try 阶段预留的业务资源。Confirm 操作要求满足幂等性，失败后要重试
- Cancel 阶段：取消执行，释放 Try 阶段预留资源。Cancel 操作也需要幂等性，失败要重试

优点：
- 并发度高，无需长期锁定资源
- 一致性较好
- 适用于对中间状态有约束的业务

缺点：
- 开发复杂，需要提供 Try、Confirm、Cancel 接口

## 5. 本地消息表
本地消息表这个方案最初是 ebay 架构师 Dan Pritchett 在 2008 年发表给 ACM 的文章。设计核心是将需要分布式处理的任务通过消息的方式来异步确保执行 大致流程：生产者服务收到订单，则在 DB 写入该订单，并在同一个事务写一条订单消息到消息表；存在一个定时器轮询消息表，发送未发送的消息到 MQ，下游消费者消费后进行下游业务操作，完成后更新订单状态

{{< image src="https://webp.slightsnow.com/2024/12/8490b43bf17d008084edc98c4457a3a7.png" caption="202412041918999" height="800" width="550" >}}

容错机制：
- 扣减余额事务 失败时，事务直接回滚，无后续步骤
- 轮询生产消息失败， 增加余额事务失败都会进行重试

优点：
- 长事务仅需要分拆成多个任务，使用简单

缺点：
- 生产者需要额外的创建消息表
- 需要定时器轮询
- 消费者的逻辑如果无法通过重试成功，那么还需要更多的机制，来回滚操作

适用于可异步执行的业务，且后续操作无需回滚的业务

## 6. 事务消息
在上述的本地消息表方案中，生产者需要额外创建消息表，还需要对本地消息表进行轮询，业务负担较重。 阿里开源的 RocketMQ 4.3 之后的版本正式支持事务消息，该事务消息本质上是把本地消息表放到 RocketMQ 上，解决生产端的消息发送与本地事务执行的原子性问题

**注意 Kafka 和 Pulsar 的事务消息和 RocketMQ 的事务消息并不是同一个概念**

可以参考：[浅谈 RocketMQ、Kafka、Pulsar 的事务消息 - DockOne.io](http://dockone.io/article/2434599)

事务消息发送及提交：
- 发送消息（half 消息）
- 服务端存储消息，并响应消息的写入结果
- 根据发送结果执行本地事务（如果写入失败，此时 half 消息对业务不可见，本地逻辑不执行）
- 根据本地事务状态执行 Commit 或者 Rollback（Commit 操作发布消息，消息对消费者可见）

容错机制： 对没有 Commit/Rollback 的事务消息（pending 状态的消息），从服务端发起一次“回查” Producer 收到回查消息，返回消息对应的本地事务的状态，为 Commit 或者 Rollback 事务消息方案与本地消息表机制非常类似，区别主要在于原先相关的本地表操作替换成了一个反查接口

优点：
- 长事务仅需要分拆成多个任务，并提供一个反查接口，使用简单

缺点：
- 消费者的逻辑如果无法通过重试成功，那么还需要更多的机制，来回滚操作

适用于可异步执行的业务，且后续操作无需回滚的业务

## 7. 最大努力通知
最大努力通知是最简单的一种柔性事务，适用于一些最终一致性时间敏感度低的业务，且被动方处理结果 不影响主动方的处理结果 大致意思：
1. 系统 A 本地事务执行完之后，发送个消息到 MQ
2. 这里会有个专门消费 MQ 的服务，这个服务会消费 MQ 并调用系统 B 的接口
3. 要是系统 B 执行成功就 ok 了；要是系统 B 执行失败了，那么最大努力通知服务就定时尝试重新调用系统 B， 反复 N 次，最后还是不行就放弃

与前面本地消息表和事务消息方案对比，区别： 可靠消息一致性，发起通知方需要保证将消息发出去，并且将消息发到接收通知方，消息的可靠性关键由发起通知方来保证。 最大努力通知，发起通知方尽最大的努力将业务处理结果通知为接收通知方，但是可能消息接收不到，此时需要接收通知方主动调用发起通知方的接口查询业务处理结果，通知的可靠性关键在接收通知方

解决方案上，最大努力通知需要：
- 提供接口，让接受通知方能够通过接口查询业务处理结果
- 消息队列 ACK 机制，消息队列按照间隔 1min、5min、10min、30min、1h、2h、5h、10h 的方式，逐步拉大通知间隔 ，直到达到通知要求的时间窗口上限。之后不再通知

最大努力通知适用于业务通知类型，例如微信交易的结果，就是通过最大努力通知方式通知各个商户，既有回调通知，也有交易查询接口

## 8. SAGA
Saga 是 1987 年普林斯顿大学的 Hector Garcia-Molina 和 Kenneth Salem 发表的数据库论文 Sagas 提到的一个方案。其核心思想是将长事务拆分为多个本地短事务，由 Saga 事务协调器协调，如果正常结束那就正常完成，如果某个步骤失败，则根据相反顺序依次调用补偿操作
Saga 一旦到了 Cancel 阶段，那么 Cancel 在业务逻辑上是不允许失败了。如果因为网络或者其他临时故障，导致没有返回成功，那么 TM 会不断重试，直到 Cancel 返回成功
论文里面的 SAGA 内容较多，包括两种恢复策略，包括分支事务并发执行等等，可以参考 [Managing data consistency in a microservice architecture using Sagas - part 1](http://chrisrichardson.net/post/microservices/2019/07/09/developing-sagas-part-1.html) 来学习

恢复策略：
1. 向后恢复：如果任一子事务失败，补偿所有已完成的事务
2. 向前恢复：重试失败的事务，假设每个子事务最终都会成功（这种情况不需要提供补偿能力）

注意：Saga 并不支持 ACID 的 I 也就是隔离性，需要业务层面自行解决 应对论文方案隔离性的缺失，Seata 用到了状态机（[Seata Saga 模式](http://seata.io/zh-cn/docs/user/saga.html)）

Saga 是一种“长事务的解决方案”，更适合于“业务流程长、业务流程多”的场景 使用场景举例：用户在某平台下一个关联订单，包含机票预订、租车、酒店预订、支付等流程，如果所有动作都成功，则事务完成，否则所有流程要补偿（并不一定是回滚，比如机票、租车的子订单状态变为取消预订而不是删除订单）

优点：
- 一阶段提交本地事务，无锁，高性能
- 参与者可异步执行，高吞吐
- 补偿服务易于实现，因为一个更新操作的反向操作是比较容易理解的

缺点：
- 原始方案不支持隔离性

## 9. AT 事务模式
这是阿里开源项目 [seata](https://link.segmentfault.com/?enc=SrFLYk2ptJZQGaSgAij8EQ%3D%3D.4yMleapOCMOQBDilTkHcxvxEKXpB26k2v8dSbZ6DlYg%3D) 中的一种事务模式，在蚂蚁金服也被称为 FMT。优点是该事务模式使用方式，类似 XA 模式，业务无需编写各类补偿操作，回滚由框架自动完成，缺点也类似 XA，存在较长时间的锁，不满足高并发的场景。从性能的角度看，AT 模式会比 XA 更高一些，但也带来了脏回滚这样的新问题。有兴趣的同学可以参考 [seata-AT](https://link.segmentfault.com/?enc=mKonktr2%2FweP8b%2F1Ew8L9w%3D%3D.37mnrB0TRmWstI8kuiXqEsBTlL3FibfWDEyBFDq%2FHJixhtv9tEV1Fk9tSsGaY%2BBYGuQNRPxYVkHI%2BNWs6%2FxRAQ%3D%3D)

## 10.  微信事件中心
[微信事件中心 - 高可靠、高可用的事务消息平台（腾讯内网）](https://km.woa.com/group/23979/articles/show/333809?kmref=search&from_page=1&no=1)

分两种模式
1. 普通消息，本质是把所有相关事务都异步化执行，依赖消息队列驱动的无限重试机制，保证最终全部成功
2. 基于事件中心实现的两阶段提交，看上去是上文提到的 事务消息+两阶段提交 的组合模式，具体设计原由及选用场景见文章即可

个人理解划分这两种模式，是因为微信业务接入的第一步和前文所述的本地消息表&&事件消息模式不太一样造成的。微信这里的模式是，业务要执行事务（无论主事务还是从事务），第一步都是向事件中心提交请求；而前者的操作是主事务执行成功后才会生成消息触发从事务

## 11. 异常处理及一些开发实践
分布式事务组件会遇到的一些经典问题：
- 空回滚（比如 TCC 中 Cancel 了一个没有 Try 的事务）
- 请求重复（这种比较常见，要处理订单号幂等）
- 悬挂（比如 TCC 中因时序问题，导致 Cancel 比 Try 先收到），解决方法可以参考开源组件 [DTM 的 子事务屏障 | DTM 教程](https://dtm.pub/practice/barrier.html#%E5%AD%90%E4%BA%8B%E5%8A%A1%E5%B1%8F%E9%9A%9C) 机制

开发角度： 既然是事务，无论是否分布式，在业务层面都要注意有一个自始至终的唯一事务标识，比如订单号。且各个业务接口实现都要注意幂等和可重入逻辑

了解使用的是强一致还是最终一致，明确最终一致的方案对用户的影响，是否需要给用户一些友好提示

可以发现，分布式事务的可靠实现，最底层的唯一手段就是 **`错误重试`**，但在写重试逻辑的时候，要非常注意，不要过分暴力，在系统异常的时候，很可能暴力的重试会加剧系统异常，甚至引发雪崩。比较常见的方法是控制重试次数（RPC 重试最多不要超过 3 次，消息重放次数不要超过 50 次，异常消息最好转到死信队列处理），或控制重试的时延（比如 1s、2s、4s、8s… 指数退避策略）

无论对自己的架构设计多么自信，对账环节都必不可少，在一开始设计业务流程和数据结构的时候，就要提前考虑如何抽象统一，方便后续对账系统的开发，以及如何降低新业务接入对账系统的复杂性，这里还是挺有挑战的

运营安全角度： 注意一个原则，会对用户产生利益的事务，尽量放到最后再执行（比如一个抽奖业务，先抽奖发奖，然后再扣用户奖券或虚拟币，如果第二步有失败或延迟，会造成问题）。但还要考虑另一个因素，比如 A 相比 B 来说业务逻辑复杂很多，失败率高，那这种情况要考虑优先执行 A。尽量避免先执行 B，后执行 A 失败要回滚 B 的问题

回滚、补偿的考虑因素： 在分布式事务场景下，业务和架构设计，**尽量能够不回滚（补偿）**，而是尽力向前（即 Saga 中的向前恢复），可以大大减轻开发运维复杂度 另外需要注意回滚、补偿的时效性是否能够接受，在未达到最终一致前，系统的中间态是否会暴露给用户，以及暴露给用户是否在产品层面能接受