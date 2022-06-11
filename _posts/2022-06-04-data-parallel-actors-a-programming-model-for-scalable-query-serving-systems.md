---
layout: post
title: "Data-Parallel Actors: A Programming Model for Scalable Query Serving Systems"
intro: After this paper, I'll be switching gears a bit and reading/writing about papers from NSDI 2022. These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions!
categories:
---

[Data-Parallel Actors: A Programming Model for Scalable Query Serving Systems](https://www.usenix.org/system/files/nsdi22-paper-kraft.pdf)

## What is the research?

The research describes an actor-based framework{% sidenote 'actor' "Actors are a programming paradigm where one deploys multiple independent units that communicate through messages - [here](https://www.brianstorti.com/the-actor-model/) is one resource on the approach." %} for building _query-serving systems_, a class of database that predominantly respond to read requests and frequent bulk writes. The paper cites several examples of these systems, including Druid (covered in a [previous paper review](2022/05/15/druid-a-real-time-analytical-data-store.html)) and [ElasticSearch](https://github.com/elastic/elasticsearch).

The paper argues that _query-serving systems_ are a common database deployment pattern sharing many functionalities and challenges (including scaling in cloud environments and recovery in the face of failure). Rather than relying on shared implementations that enable database scaling and fault tolerance, _query-serving systems_ often reinvent the wheel{% sidenote 'choose' "Or choose not to provide functionality."%}. Custom implementations incur unnnecessary developer effort and require further optimizations beyond the initial implementation. For example, Druid clusters provide scaling using a database-specific implementation, but often end up overprovisioning{% sidenote 'druidscaling' "The paper cites [Popular is cheaper: curtailing memory costs in interactive analytics engines](https://blog.acolyer.org/2018/06/15/popular-is-cheaper-curtailing-memory-costs-in-interactive-analytics-engines/), an article about Yahoo/Oath's efforts to improve the provisioning of their Druid cluster."%}. Sometimes _query-serving systems_ take a long time to develop their own implementation of a feature - for example, Druid's implementation of joins{% sidenote 'druidjoin' "Druid's join support was proposed [in 2019](https://github.com/apache/druid/issues/8728), many years after the project's initial release."%}, and MongoDB's implementation of consensus{% sidenote 'mongonote' "MongoDB replication is covered by [
Fault-Tolerant Replication with Pull-Based Consensus in MongoDB](https://www.usenix.org/conference/nsdi21/presentation/zhou), which is very interesting in and of itself. :)"%}.

{% maincolumn 'assets/dpa/table2.png' '' %}

The DPA paper aims to simplify development, scaling, and maintenace of _query-serving systems_, using a runtime based on stateful actors. While the idea of building distributed systems on top of stateful actors is not necessarily new{% sidenote 'orleans' "Examples of using stateful actors exist in [Orleans](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/Orleans-MSR-TR-2014-41.pdf) and [Ray](https://www.micahlerner.com/2021/06/27/ray-a-distributed-framework-for-emerging-ai-applications.html)." %}, implementing a database runtime targeted at a common class of databases (_query-serving systems_) is novel.

{% maincolumn 'assets/dpa/figure1.png' '' %}

## What are the paper's contributions?

The paper makes three main contributions:

- Identifying and categorizing _query-serving systems_, a class of databases supporting "low-latency data-parallel queries and frequent bulk data updates"
- A _Data Parallel Actor (DPA)_ framework aimed at simplifying the implementation of _query-serving systems_ using stateful actors.
- Porting several _query-serving systems_ to the _Data Parallel Actor_ paradigm, then evaluating the performnace of the resulting implementations.

## How does the system work?

### Actors and Data

Actors are a key component of the _DPA_ framework - several ideas from existing databases are reworked to fit an actor-based model, in particular _partitioning_, _writes_, and _reads_.

Many databases use _partitioning_ to address problems related to fault tolerance, load balancing, and elasticity{% sidenote 'partitions' "Partitioning a dataset increases _fault tolerance_ because a partitioned dataset can be scaled by adding more copies of each partition - if any one of them fails, requests can be forwarded to another copy. The paper cites the Shard Manager paper (covered by a [previous paper review](https://www.micahlerner.com/2022/01/08/shard-manager-a-generic-shard-management-framework-for-geo-distributed-applications.html)), when discussing this idea of forwarding requests. A partitioned dataset is also easier to _load balance_ because partitions can be shifted independently away from "hotspots", distributing load across more machines. Lastly, partitioning increases _elasticity_ by facilitating capacity increases in response to additional load - new machines can be started, each containing additional copies of partitions." %}.  DPA adapts partitioning by assigning partitions of a dataset to an actor. Actors manage partitions using a limited set of methods (including `create`, `destroy`, `serialize`, and `deserialize`) that a database developer implements according to the internals of their project.

The paper describes several advantages to the actor-based approach - in particular, building a distributed database on top of the DPA-based actor abstraction simplifies the implementation of fault tolerance, load balancing, and elasticity that databases would otherwise build themselves (or not at all). Rather than each _query-serving system_ custom-writing these featuresets, the DPA framework handles them. In turn, the main component that developers become responsible for is implementing the Actor interface with the DPA framework.

{% maincolumn 'assets/dpa/figure2.png' '' %}

### Write handling

To handle _writes_, a _query-serving system_ based on DPA implements an `UpdateFunction` (accepting parameters like the table to be updated, the records to change or add, and the consistency{% sidenote 'consistency' "Consistency relates to how data updates are processed and reflected in the system - for example, does the system fail a transaction if some of its writes fail? The [Jepsen](https://jepsen.io/consistency) content is one of the resourcs I commonly reference. If you like any other resources on the topic feel free to send a pull request!"%} of the update). The DPA framework then determines which actors need to be updated (and how) under the hood. Importantly, DPA supports building _query-serving systems_ with different consistency guarantees, from [eventually consistent](https://www.allthingsdistributed.com/2008/12/eventually_consistent.html) to [full serializability](https://jepsen.io/consistency/models/serializable) - depending on the consistency level chosen, the update has different behavior. This configurability is useful because consistency requirements vary by _query-serving system_.

### Read handling

{% maincolumn 'assets/dpa/figure3.png' '' %}

To handle _reads_, DPA uses a client layer for receiving queries. The client layer converts queries into `ParallelOperators` that can be run across many actors as needed. Example of `ParallelOperators` are _Map_ (which "applies a function to actors in parallel and materializes the transformed data."), and _Scatter and Gather_ (a ["collective"](https://mpitutorial.com/tutorials/mpi-scatter-gather-and-allgather/) operation used in functionality like like joins).

### Architecture

The _DPA_ paper discusses a runtime (called _Uniserve_) for running _query-serving systems_ using an actor-based model. The runtime has four high-level components: a _query planner_, a _client layer_, _the server layer_, and a _coordinator_.

{% maincolumn 'assets/dpa/figure4.png' '' %}

The _query planner_ is responsible for receiving queries from clients, and "translates them to DPA parallel operators (or update functions)" - in other words, determining which partitions and actors the query needs to access. The paper discusses how developers can (or need to) implement the query planner themselves, which seemed related to the idea of creating a general query planner (discussed in existing research like [F1](http://www.vldb.org/pvldb/vol11/p1835-samwel.pdf)).

The _client layer_ communicates with the query planner, fanning out subqueries to the deeper layers of the Uniserve stack - in particular the nodes with actors and the partitions they are associated with.

Actors (and the partitions they are responsible for) live in the _Uniserve Server Layer_. There are many nodes in this layer, each with several actors and their associated partitions. The nodes in this layer communicate with one another in order to execute queries (like _Scatter and Gather_ operations) and replicate data from one actor to another as needed.

Lastly, the allocation of actors to servers is handled by the _coordinator_. The _coordinator_ scales the system by adding or removing servers/actors in response to demand, in addition to managing fault tolerance (by ensuring that there are multiple replicas of an actor, all of which converge to the same state through replication).

## How is the research evaluated?

In addition to establishing the paradigm of DPA, the paper also discusses how several existing databases were ported to the approach, including [Solr](https://solr.apache.org/), [MongoDB](https://www.mongodb.com/), and [Druid](https://www.micahlerner.com/2022/05/15/druid-a-real-time-analytical-data-store.html). The implementations of these databases on DPA is significantly shorter with respect to lines of code:

> DPA makes distributing these systems considerably simpler; each requires <1K lines of code to distribute as compared to the tens of thousands of lines in custom distribution layers (~90K in Solr, ~120K in MongoDB, and ~70K in Druid).

The paper also measures overheads associated with the DPA model by comparing native systems to the comparable system on DPA, finding that the approach adds minimal overhead.

{% maincolumn 'assets/dpa/figure5.png' '' %}

Another key feature of DPA is its ability to generally load balance actors and partitions. To test this behavior, the system executed skewed queries that introduce "hot spots" in the cluster - the _coordinator_ component is able to dissipate "hot spots" across machines while scaling actors.

{% maincolumn 'assets/dpa/figure9.png' '' %}

The evaluation also considered how a DPA system scaled in response to load - autoscaling while limiting load balancing and managing faults is difficult{% sidenote 'evenif' "Even if some databases like [Redshift](https://dl.acm.org/doi/abs/10.1145/2723372.2742795) or [Snowflake](https://dl.acm.org/doi/pdf/10.1145/2882903.2903741) make it look easy!" %}

{% maincolumn 'assets/dpa/figure10.png' '' %}

## Conclusion

The DPA paper combines several ideas from existing research in a novel way - in particular, it draws on ideas related to deploying actor-based systems like [Ray](https://www.micahlerner.com/2021/06/27/ray-a-distributed-framework-for-emerging-ai-applications.html) and [Orleans](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/Orleans-MSR-TR-2014-41.pdf).

It would be interesting to learn how the DPA design performs for other types of database deployments{% sidenote 'mongo' "One example would be MongoDB used with a different (non- _query-serving system_) access pattern."%}. For example, how does the DPA paradigm work for OLTP workloads? Are the overheads associated with the paradigm too high (and if so, can they be managed)?

I'm looking forward to seeing answers to these questions, along with further developments in this space - a unified framework for building _query serving systems_ would likely be useful for the many different teams working on similar problems!