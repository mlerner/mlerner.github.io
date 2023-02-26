---
layout: post
title: "Meta’s Next-generation Realtime Monitoring and Analytics Platform"
categories:
---

[Meta’s Next-generation Realtime Monitoring and Analytics Platform](https://www.vldb.org/pvldb/vol15/p3522-mo.pdf)

## What is the research?

Many companies perform real time analytics in order to customize user experiences or alert on anomalous behavior - other examples from industry include Netflix's [open source Mantis platform](https://netflixtechblog.com/open-sourcing-mantis-a-platform-for-building-cost-effective-realtime-operations-focused-5b8ff387813a) or open source projects like [Apache Beam](https://beam.apache.org/){% sidenote 'druid' "Druid, the subject of one such system is the subject of a [previous paper review](https://www.micahlerner.com/2022/05/15/druid-a-real-time-analytical-data-store.html)!"%}. Meta performed this function using a system called _Scuba_, described in published research from [VLDB 2013](https://research.facebook.com/file/2964294030497318/scuba-diving-into-data-at-facebook.pdf). While the existing system scaled to meet initial demand, over time operational and usability issues led to an internal push to evolve the system.

The newly published research describes the system that came from this work, codenamed _Kraken_. Unlike Scuba, Kraken optimizes for configurability, allowing users to specify which tradeoffs they want to make around their dataset - for example, faster availability of a dataset can be balanced against the consistency of query results{% sidenote 'concrete' 'To make this more concrete, user queries in Scuba would go to one of several copies of dataset. Depending on how each deployment of Scuba happened to have ingested the data, repeating the same query, but to different deployments, could return "inconsitent results."'%}.

The paper provides technical references to the underlying primitives that Kraken is built on - one of which, [Shard Manager](https://www.micahlerner.com/2022/01/08/shard-manager-a-generic-shard-management-framework-for-geo-distributed-applications.html), was a previous paper review. Beyond describing the architecture of the system, the paper also discusses the experience of replacing the existing system.

## Background and Motivation

Before diving into the details of the implementation, the paper does a thorough explanation of the design space of systems like Scuba, focusing on six main facets:

- _Query performance_: how quickly does the system respond to users?
- _Freshness_: how up to date is the data served by the system?
- _Availability_: what does the system do under different failure modes? Is data available at all, or can the system return partial results in a degraded state?
- _Dataset size_: how much data can the system actually store and serve in a performant way?
- _Resource efficiency_: how much resources (and of what type) does a system require in order to operate? Are the resources used all of the time, or just when responding to queries?
- _Features_: is the system configurable for different use cases? Does it offer features like backfills and a SQL-like interface?

Different databases weight these facets according to the system's intended use. The paper focuses on three main categories of tradeoffs:

- _Data-warehouses_, which store large amounts of data, and are not on the path of a user's interactive session{% sidenote 'snowflake' 'Snowflake, [described in a previous paper review](https://www.micahlerner.com/2023/01/19/elastic-cloud-services-scaling-snowflakes-control-plane.html), is one such example.'%}.
- _Online analytical processing (OLAP)_ databases, used for analytics and medium-size datasets{% sidenote 'napa' "The paper notes that many modern OLAP databases are configurable for specifics use cases - in particular [Napa](https://research.google/pubs/pub50617/)."%}
- _Real-time monitoring systems_, which optimize for quickly surfacing up-to-date datasets in as complete a form as possible.

{% maincolumn 'assets/kraken/figure1.png' '' %}

While each category makes fundamentally different tradeoffs, they all have similar high-level components in their read and write paths. For example, databases need to ingest data, and some may implement "write-side optimizations" (like creating different views of the underlying dataset{% sidenote 'materialized' "These are often called [materalized views](https://en.wikipedia.org/wiki/Materialized_view). [This article](https://materialize.com/guides/materialized-views/) by Materialize also provides helpful context."%}). Storage for the underlying dataset is important, although different applications have different availability requirements.

{% maincolumn 'assets/kraken/figure2.png' '' %}

This context is helpful for understanding the _why_ behind Scuba's design, as well as  its potential shortcomings as a real-time monitoring system. For example, the initial system sacrified features like joins in order to support better query performance. It also optimized for the common case and built a single index, improving resource efficiency - at the same time, applications not using that index experienced slower query performance. Lastly, Scuba optimized for durability and availability by designing its engine to return results, even if those results were imperfect{% sidenote 'tail' "This problem could happen due to machines randomly failing or performing poorly, similar to what is described in [The Tail at Scale](https://www.barroso.org/publications/TheTailAtScale.pdf)."%}.

In contrast, Kraken was designed to make different tradeoffs than Scuba from the outset, specifically focusing on improving user experience and reducing the need for maintenance.

For example, Kraken aimed to provide consistent results to user queries by limiting divergence between copies of a dataset. This approach was unlike Scuba's, which stored multiple independently-updated copies, each subject to drift from factors like underlying machines going offline - consequently, user queries received significantly varying results depending on the copy they communicated with (even when running the same query).

On the operational complexity front, Kraken aimed to take advantage of automation that would limit complicated manual interventions for operations and scaling. For example, Scuba often required configuration changes to perform updates on underlying hardware. Similarly, insufficient load balancing and load spikes to machines in the system would regularly cause crashes, but scaling resources in response was non-trivial.

## What are the paper's contributions?

The paper makes three main contributions:

- Description of the previous system, characterizing the problem space and motivating improvements.
- Design and implementation of the new system, called _Kraken_, at scale.
- Evaluation of the system and a description of the migration to it over time.

## How does the system work?

Kraken can be broken down into three main components:

- _Real-time Ingestion_, which covers how the logs make it into the system and become available to query.
- _Backup_, which allows persistence of the dataset for long periods of time in an optimized format.
- _Reads_, by which user queries access the stored information.

{% maincolumn 'assets/kraken/figure3.png' '' %}

### Ingestion

To ingest data, Kraken implements three main components: _writing raw logs_, _reading and operating on the raw logs_, and _deployment of log data to machines_.

_Scribe_ is the first step in ingesting raw logs{% sidenote 'scribe' "There are a few great resources around Scribe, my favorite of which is [The History of Logging @ Facebook](https://www.usenix.org/conference/lisa18/presentation/braunschweig). There is also a post on Scribe from Meta's engineering blog [here](https://engineering.fb.com/2019/10/07/data-infrastructure/scribe/). Scribe appears to at one point have been [open source](https://github.com/facebookarchive/scribe), but is now archived - my assumption is Meta still maintains an internal fork."%}. Applications log individual entries to a partitioned dataset (called a category), and Scribe notifies downstream systems who are "tailing" the logs.

To reliably read and operate on incoming raw logs at Facebook scale, Kraken uses a distributed framework called _Turbine_. Turbine schedules "tailer" jobs over many different machines in Meta's fleet, scaling by adjusting the number of tailers according to load, and rescheduling failed tailers on new machines. The primary job of each tailer job is transforming the logs into a structured and organized format named _RowBlocks_ - the incoming data is not guaranteed to be the same structure as the output dataset surfaced to the user.

Before completing its processing of a _RowBlock_, a tailer needs to determine which machines should store the final product. This decision is based on two pieces of information about the _RowBlock_ - the input dataset it is associated with, and the _partition_ of the dataset{% sidenote 'determ' "The paper mentions this is created via a deterministic mapping, but doesn't provide exact information on how this mapping works." %}. The output of this calculation is a _ShardId_ corresponding to the unit of scaling Kraken uses to respond to more requests (sharding is discussed in more detail further down). Kraken then uses the _ShardId_ to write multiple copies of the _RowBlock_ to an ordered, immutable, distributed log system called [LogDevice](https://engineering.fb.com/2017/08/31/core-data/logdevice-a-distributed-data-store-for-logs/){% sidenote 'logdevice' 'LogDevice also [appears to have been an open source project](https://logdevice.io/) at one point.' %} on machines spread across Meta's network.

To make the distributed log available for user queries, machines in the fleet (called _leafs_) fetch it. Each _leaf_ is assigned shards based by _Shard Manager_{% sidenote 'shardman' "My previous paper review on Shard Manager is [here](https://www.micahlerner.com/2022/01/08/shard-manager-a-generic-shard-management-framework-for-geo-distributed-applications.html)." %}. To assign shards to leafs, _Shard Manager_ takes into account factors like the load on different parts of a dataset (subdivided into a scaling unit called shards). If a shard is under heavy load, _Shard Manager_ instructs more leaf nodes to maintain a copy of it. It also handles data-management tasks, like removing shards of datasets that should no longer be stored (according to a configured retention policy).

### Remote Backup and Compaction

New data entering the system is only temporarily stored in the distributed log - the _LogDevice_ is a fixed size, so accepting new entries can only happen if data "ages out" of short-term storage. This eviction implementation poses a problem if users want to query the underlying entries - to solve this, Kraken backs up data using a _Backup Compaction Service (BCS)_.

_BCS_ periodically reads data from the _LogDevice_, combining multiple blocks, compressing them, and writing the output to a blob storage system. After completing the transfer, _BCS_ creates an entry in the _LogDevice_. When performing further reads, leafs interpret this entry as an instruction to read previous data from blob storage, rather than from the distributed log.

{% maincolumn 'assets/kraken/figure4.png' '' %}

The backup and compaction process increases storage effiency (due to the compression technique), while lowering disk IO (to read the same amount of data, Kraken leaf nodes can perorm fewer disk accesses due to the larger individual size).

### Read Path

When a user issues a query for data stored in Kraken, a _root node_ executes the query by parallelizing it across relevant machines storing partitions of the data. The paper mentions that this "query architecture is largely retained from legacy Scuba", and relies on multiple levels of aggregators that fanout requests{% sidenote 'agg' "The aggregator pattern also shows up in a previous paper review on [Monarch: Google’s Planet-Scale In-Memory Time Series Database](https://www.micahlerner.com/2022/04/24/monarch-googles-planet-scale-in-memory-time-series-database.html)." %}.

{% maincolumn 'assets/kraken/scubaarch.png' '' %}

When executing the query, Kraken also evaluates whether it needs to access data that is no longer stored in the core system. This "out of retention" data can be stored in other Meta internal systems, but the query interface abstracts this away from the user{% sidenote 'f1query' "This abstraction is similar to those of [F1 Query](http://www.vldb.org/pvldb/vol11/p1835-samwel.pdf), a system from Google which facilitates querying hetoregenous datasets using the same interface."%}.

## How is the research evaluated?

The paper evaluates the new architecture in two main ways. First, the authors describe Kraken's productionization, representing whether investments in reliability and ease of use paid off. Second, the research evaluates the performance when launched to users.

#### Productionaization

The paper talk about migrating from the original system to its new incarnation with minimal impact on users. While independently deploying Kraken code (with no interaction between new and old systems) posed little problem, moving the underlying data and testing performance of the new system under was more of a challenge.

One main performance hurdle that the team faced was switching to a globally-distributed deployment performing cross-region operations. Previously, each region updated its dataset separately (potentially leading to user-facing consistency differences).

An example of this shift was on the ingestion path - previously, Scuba sent new log entries to each region independently and didn't wait for notification of a successful write. In contrast, Kraken writes of _RowBlocks_ to _LogDevices_ could span multiple regions, and _would_ block on acknowledgement (introducing potential latency). The team addressed this problem by batching writes, amoritizing the latency overhead of cross-region operations.

Ensuring that the underlying data was completely transferred to Kraken was another challenged in the productionization process. To make sure new data was present in both Scuba and Kraken, a single group of tailers began writing data for both the new and old systems. For historical data, the migration was a bit more complicated. Wholesale copying the existing dataset for a Scuba deployment could lead to duplicates if the cutover to Kraken didn't happen instantaneously - the new tailers would start by writing logs to both Kraken and Scuba, so an entry already in Kraken could be in the Scuba copy of the dataset. Furthermore, turning off writes to Scuba without having Kraken online could lead to data loss. To solve this challenge, the authors labeled data ingested into both Kraken and Scuba. Copying data from a Scuba deployment to Kraken excluded this labeled data (as it was guaranteed to exist in the new system).

Lastly, reliability of Kraken at scale was one concern of switching. To test this, the paper discusses conducting "drain tests" to trigger the system's rebalancing process (managed by _Shard Manager_), while monitoring performance and ability to adapt. Additionally, the authors forced failure in different components of the system and watch its recovery{% sidenote 'chaos' "This is commonly called _Chaos Engineering_, was [popularized by Netflix](https://arxiv.org/pdf/1702.05843.pdf)."%}.

#### Experiments

To understand the performance of the new system, the paper considers three main metrics: _query latency_, _ingestion performance_, and _recovery under failure conditions_.

When measuring _query latency_, the paper considers production datasets of different sizes and characteristics, observing that overall latency decreased between Kraken and Scuba deployments. The authors argue the Kraken's ability to determine which shards of a dataset are under load (and scale them) is responsible for this effect - unlike Scuba's design (which doesn't create a deterministic mapping between data and the machines it lives on), Kraken definitively knows where data is. As a result, it can wait for only those partitions of the dataset to respond. Kraken's reliance on fewer partitions also adds another advantage: querying fewer partitions for data incurs lower network overhead.

{% maincolumn 'assets/kraken/table1.png' '' %}

{% maincolumn 'assets/kraken/figure5.png' '' %}
{% maincolumn 'assets/kraken/figure6.png' '' %}

Relative to Scuba, Kraken's ingestion latency also significantly decreased{% sidenote 'factor' "From my reading, the paper doesn't attribute any specific factor to lowering ingestion latency."%}, leading to fresher logs, and a better experience for users (who are relying on up to date information when querying).

{% maincolumn 'assets/kraken/table2.png' '' %}

Lastly, the paper measures recovery from failure (in particular targeting leaf nodes), using shard availability as a proxy for recovery (more shards corresponds to a greater share of the logs being available for queries). After eliminating 10% of the shards in a deployment, Kraken is able to recover to the baseline within 3 hours - the paper doesn't note whether they would be able to decrease this recovery time further (potentially  by taking action scaling capacity).

{% maincolumn 'assets/kraken/figure7.png' '' %}

## Conclusion

The paper on Kraken contains a useful case study on evolving an existing tool to new demands. The underlying system builds on many Meta-internal pieces of infrastructure (like Shard Manager and LogDevice), and having background context from previous paper reviews, I enjoyed learning how the system was built on top of these primitives -  oftentimes papers elide the underlying implementation of the systems they are relying upon, but that is certainly not true in this case.

While Kraken is remarkably similar to existing databases, like Druid{% sidenote 'druid' "Druid was the subject of a [previous paper review](https://www.micahlerner.com/2022/05/15/druid-a-real-time-analytical-data-store.html)."%}, the research is also novel in describing the reasoning behind different tradeoffs (with the added benefit of learning from a previous system deployed internally at scale).