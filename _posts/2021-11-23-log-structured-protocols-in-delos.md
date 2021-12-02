---
layout: post
title: "Log-structured Protocols in Delos"
categories:
---

_The papers over the next few weeks will be from [SOSP](https://sosp2021.mpi-sws.org/). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

[Log-structured Protocols in Delos](https://dl.acm.org/doi/10.1145/3477132.3483544)

This week's paper review, "Log-structured Protocols in Delos" discusses a critical component of Delos, Facebook's system for storing control plane data, like scheduler metadata and configuration{% sidenote 'adrian' "A previous paper on the system, [Virtual Consensus in Delos](https://www.usenix.org/conference/osdi20/presentation/balakrishnan), won a best paper award at OSDI 2020. There are great overviews of this paper from [Murat Demirbas](https://muratbuffalo.blogspot.com/2021/01/virtual-consensus-in-delos.html) and [The Morning Paper](https://blog.acolyer.org/2020/11/09/delos/), and a great talk from Mahesh at [@scale](https://atscaleconference.com/2021/03/15/virtualizing-consensus/)." %} - according to the authors, Delos is replacing Zookeeper{% sidenote 'zookeeper' 'From the [Zookeeper site](https://zookeeper.apache.org/): "ZooKeeper is a centralized service for maintaining configuration information, naming, providing distributed synchronization, and providing group services. All of these kinds of services are used in some form or another by distributed applications. Each time they are implemented there is a lot of work that goes into fixing the bugs and race conditions that are inevitable. Because of the difficulty of implementing these kinds of services, applications initially usually skimp on them, which make them brittle in the presence of change and difficult to manage. Even when done correctly, different implementations of these services lead to management complexity when the applications are deployed."'%} inside of Facebook{% sidenote 'zelos' "The authors call the Zookeeper implementation on Delos _Zelos_ - more on this later on in this paper review."%}.

Storage systems for control plane data are placed under different constraints than systems that store application data - for example, control plane systems must be highly available and strive for zero-dependencies. At the same time, it is not sufficient to provide a single API (like a simple key-value store) for control plane databases, meaning that several systems need to be implemented according to these requirements. Delos aims to limit duplicate solutions to the problems that control plane databases face by providing a common platform for control plane databases. 
 
A key feature of Delos is a replicated log - many systems use log replication to maintain multiple copies of a dataset or to increase fault tolerance{% sidenote 'log replication' "Two examples are MySQL replication, covered in previous papers reviews on [TAO: Facebook’s Distributed Data Store for the Social Graph](/2021/10/13/tao-facebooks-distributed-data-store-for-the-social-graph.html) and [Scaling Memcache at Facebook](/2021/05/31/scaling-memcache-at-facebook.html)."%}. Consumers of a replicated log execute logic on the data in log entries to produce a "state of the world". Each node that has consumed the log up to the same point will have the same "state of the world" (assuming that the log consumption code is deterministic!). The name for this technique is _state machine replication_{% sidenote 'smr' "The paper cites [Raft](https://raft.github.io/), which I wrote about in a [previous paper review](/2020/05/08/understanding-raft-consensus.html). I also highly recommend like [this overview](https://eli.thegreenplace.net/2020/implementing-raft-part-0-introduction/) from Eli Bendersky."%} (aka SMR).

The authors note that many systems taking advantage of _state machine replication_ unnecessarily re-implement similar functionality (like batching writes to the log). To enable code reuse, Delos implements common functionality in reusable building blocks that run under higher-level, application-specific logic. The authors call this stack-like approach _log-structured protocols_, and discuss how the technique simplifies the development and deployment of SMR systems through code-reuse, upgradability, and implementation flexibility.

## What are the paper's contributions?'

The paper makes three main contributions: the design for _log-structured protocols_, implementations of nine _log-structured protocols_ and two production databases using the abstraction, and the evaluation of the implementations scaled to a production environment.

## Log Structured Protocol Design

Each log-structured protocol has four primary components:

- _Application logic_: unique functionality that often represents the interface between the replicated state machine and an external system. On example is application logic that converts log entries into SQL statements that write to a database table.
- _Engines_: implement common functionality like batching writes to the log or backing up log entries to external storage. More information on the various _engines_ in a later section.
- _Local store_: contains the state of the world. Engines and application logic read/write to the local store, which is implemented using RocksDB.
- _Shared log_: the lowest level of the stack. A common _base engine_ handles writes and reads to the _shared log_.

{% maincolumn 'assets/log-structured-delos/stack.png' '' %}

_Engines_ are a key building block of each log-structured protocol - they allow developers to compose existing functionality and to focus on implementing a small set of custom logic. 

{% maincolumn 'assets/log-structured-delos/proposals.png' '' %}

Each engine interacts with the layers above or below through an API that relies on _proposals_:

- `propose`, used to send messages down the stack, towards the shared log.
- `apply`, used by lower level engines to transfer messages up the stack.

While responding to calls, the engines can also read or write to the LocalStore, which maintains the current state of the system. Additional calls setup the layering in a log-structured protocol (`registerUpcall`), coordinate trimming the log (`setTrimPrefix`), request all entries from a lower level engine (`sync`), and allow an engine to respond to events (using a `postApply` callback).

## Two Databases and Nine Engines

In addition to outlining the structure of _log-structured protocols_, the paper describes the implementation of a set of databases and engines using the approach.

### Databases

The paper discusses the implementation of two databases using the Delos infrastructure: _DelosTable_ and _Zelos_.

[Existing research from FB](https://engineering.fb.com/2019/06/06/data-center-engineering/delos/) describes how _DelosTable_, "offers a rich API, with support for transactions, secondary indexes, and range queries. It provides strong guarantees on consistency, durability, and availability." _DelosTable_ is used in Facebook's, "Tupperware Resource Broker{% sidenote 'twine' "I haven't had a chance to read it yet, but Tupperware is mentioned in Facebook's paper on resource management - [Twine: A Unified Cluster Management System for Shared Infrastructure](https://www.usenix.org/system/files/osdi20-tang.pdf)." %}, which maintains a ledger of all machines in our data centers and their allocation status".

_Zelos_ provides a Zookeeper-like interface that supports CRUD operations on a hiearchical structure of nodes{% sidenote 'zookeeper' "See the [Zookeeper documentation](https://zookeeper.apache.org/doc/r3.7.0/zookeeperOver.html) for more details."%} (among other, more advanced functions). 

{% maincolumn 'assets/log-structured-delos/zknamespace.jpg' 'Example Zookeeper namespace ([source](https://zookeeper.apache.org/doc/r3.7.0/zookeeperOver.html))' %}

When covering Zelos, the paper discusses how internal customer needs stemming from the Zookeeper-port shaped the Delos design{% sidenote 'pivot' 'The paper also notes another pivot: "The Delos project was initially conceived with the goal of adding a quorum-replicated Table store to this menagerie of distributed systems, filling a gap for applications that required the fault-tolerance of ZooKeeper with the relational API of MySQL. However, a secondary goal soon emerged: could we implement the ZooKeeper API on the same codebase as this new Table store, eliminating the need to maintain and operate a separate ZooKeeper service?"'%}:

> Our initial design for Delos involved a reusable platform layer exposing an SMR API, allowing any arbitrary application black box to be replicated above it. The platform itself is also a replicated state machine, containing functionality generic to applications...Unfortunately, structuring the platform as a monolithic state machine limited its reusability. When the ZooKeeper team at Facebook began building Zelos on the Delos platform, they needed to modify the platform layer to obtain additional properties such as session ordering guarantees, batching / group commit, and nonvoting modes{% sidenote 'zookeeperunique' 'These unique properties of Zookeeper are discussed in a later section'%}.

Because these unique features of Zookeeper were too difficult to implement in a monolithic architecture, the Delos design pivoted to a stack-like, engine-based approach.

### Engines

The paper describes nine different engines that comprise common functionality. I focus on three that highlight Delos' strengths: the _ObserverEngine_, _SessionOrderEngine_, and _BatchingEngine_.

{% maincolumn 'assets/log-structured-delos/nine-engines.png' '' %}

The _ObserverEngine_ is placed between different layers of a Delos stacks, and provides reusable monitoring functionality by tracking the time spent in a given engine.

{% maincolumn 'assets/log-structured-delos/stacks.png' '' %}

The _SessionOrderEngine_ implements the idea of Zookeeper sessions{% sidenote 'sessions' "The original [Zookeeper paper](https://www.usenix.org/legacy/event/atc10/tech/full_papers/Hunt.pdf) seems to discuss this idea in the _Zookeeper guarantees_ section. Documentation on mechanics of Zookeeper sessions is [here](http://zookeeper.apache.org/doc/current/zookeeperProgrammers.html#ch_zkSessions)."%}: 

> ZooKeeper provides a session-ordering guarantee: within a session, if a client first issues a write and then a concurrent read (without waiting for the write to complete), the read must reflect the write. This property is stronger than linearizability, which allows concurrent writes and reads to be ordered arbitrarily; and encompasses exactly-once semantics{% sidenote '39' "The Delos paper references [Implementing Linearizability at Large Scale and Low Latency](http://web.stanford.edu/~ouster/cgi-bin/papers/rifl.pdf) when discussing how Zookeeper's guarantees are stronger than linearizability (definition of linearizability [here](https://jepsen.io/consistency/models/linearizable)). The system proposed by this paper uses log-based recovery on the server to ensure that if clients retry a request after crashing, the system will preserve linearizability. When reading the referenced paper, I also found this [talk](https://www.youtube.com/watch?v=MkF2wuHaf04) from the authors and this review from [The Morning Paper](https://blog.acolyer.org/2015/10/22/implementing-linearizability-at-large-scale-and-low-latency/)." %}

Delos implements these semantics in the _SessionOrderEngine_ by assigning sequence numbers (essentially autoincrementing IDs) to outgoing writes. When other nodes read from the log, they check that the writes are ordered based on sequence number, reordering them into the correct sequence as necessary{% sidenote 'reorder' 'The Delos paper mentions that "disorder can occur due to leader changes within the log implementation, or due to code changes in the Delos stack".' %}.  

The _BatchingEngine_ groups entries into a single transaction write to the _LocalStore_. This approach enables higher performance and provides a common implementation that both DelosTable and Zelos use (related to Delos' design goal of code re-use).

## Evaluation

The paper evaluates Delos log-structured protocols on two dimensions: the overhead (if any) inherent to the design, and the performance/productivity gains that the design allows.

When evaluating overhead, the paper considers the `apply` thread (as this upcall relates to the different transitions between each engine). The paper notes that of the CPU consumed in the fleet, apply only makes up 10% of the utilization.

{% maincolumn 'assets/log-structured-delos/apply.png' '' %}

The second main category of results is related to the benefits of code-reuse. One example that the paper cites is the introduction of the _BatchingEngine_ discussed in the previous section. The deployment of the _BatchingEngine_ was relatively straightfoward and contributed to a 2X throughput improvement. Furthermore, the engine could be rolled out to other protocols.

{% maincolumn 'assets/log-structured-delos/batchingengine.png' '' %}

## Conclusion

I greatly enjoyed this paper! The paper's authors have been researching related topics for some time{% sidenote 'tango' "Mahesh published a [paper](http://www.cs.cornell.edu/~taozou/sosp13/tangososp.pdf) on building data structures from a shared log at SOSP'13."%}, and seeing their expertise applied to a new production setting was quite interesting. Additionally, the newest Delos papers share production-focused experiences, and a design guided by collaboration with internal customers - it is always fun to read about rubber-meets-the-road approaches!

As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback! Until next time.