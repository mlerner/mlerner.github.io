---
layout: post
title: "Meta’s Next-generation Realtime Monitoring and Analytics Platform"
categories:
---

## What is the research?

Many companies perform real time analytics n order to customize user experiences or alert on anomalous behavior (TODO link to examples from SRE book, Netflix, etc). Meta performed this function using a system called _Scuba_. Over time, there was a new internal push to evolve Scuba for modern needs. For example, Scuba was difficult to use for TODO reasons.

This paper describes the new version of the system, codenamed Kraken. Unlike Scuba, Kraken provides features like TODO.

Beyond describing the architecture of the system, the paper also discusses the experience of replacing the existing system, including the migration between new and old system.

## Background and Motivation

Before diving into the details of the design, the paper does a thorough explanation of the design space of systems like Scuba, focusing on six main facets of a database:

- Query performance:
- Freshness:
- Availability:
- Dataset size:
- Resource efficiency:
- Features:

Different types of databases weight these facets differently. In particular, the paper focuses on data-warehouses, OLAP-style databases, and real-time monitoring use-cases. For example, data-warehouses TODO. On the other hand, there are OLAP-style databases (TODO describe OLAP) like Napa, Druid, Clickhouse, etc (TODO link to Druid post).

At the same time, the different databases in the space have similar high-level components in the write and read paths. For example, databases need to ingest data, and some may implement "write-side optimizations" by creating different views of the underlying dataset. Storing the underlying dataset is important, although different applications have different availability requirements.

This context is helpful for understanding the design of Scuba along several axises. Scuba sacrified features like joins in order to support better query performance. Scuba also optimized for the common case by building a single index, improving resource efficiency, but lowering query performacne for applications not using that index. Lastly, Scuba optimized for durability and availability by designing its engine to return results, even if those results were imperfect (TODO describe stragler effect and simple way of replicating data).

Kraken was designed to make different tradeoffs than Scuba in order to improve the experience of users of the database and reduce the maintenance required to maintain the system. Kraken aimed to improve consistency such that users of a query would not receive significantly varying results each time they ran the query. The time since the data was ingested into the system shouldn't impact results, and Kraken aimed to solve this by improving durability of the underlying dataset. Lastly, the system aimed to keep data around for longer by developing techniques for long-term storage.

On the operational complexity side, Kraken aimed to simplify routine maintenance by "draining" traffic away from impacted nodes. Improve stability such that spikes in load don't topple over the impacted machines. Lastly, independently scaling storage and compute (TODO mention snowflake paper!) has been proven to work at scale while drastically improving resource efficiency.

## What are the paper's contributions?

The paper makes three main contributions:

- Description of the previous system, characterizing the problem space
- Design and implementation of the new system at scale
- Evaluation of the system and a description of the transition to it over time

## How does the system work?

The new implementation of Kraken can be broken down into three main components:

- Real-time Ingestion: how do the logs make it into the system and make it ready to query
- Backup: not all of the data can be retained for unlimited periods of time
- Read path: after ingestion, the data is compacted and made accessible for user queries

TODO figure 3

### Ingestion

To ingest data, Kraken makes implements four main components: writing-logs, reading the raw logs and reformatting them for persistent storage, and deployment of log partitions over machines.

Meta has an internal system for writing logs called Scribe. TODO link to scribe papers. Because scribe is a log-forwarding service, Kraken makes use of a distributed framework for tailing the logs called Turbine. Turbine schedules "tailer" jobs over many different machines in Meta's fleet, ensuring that the the raw logs are read in a reliable manner. These tailer jobs write the logs to disk in a structured and organized format called _RowBlocks_ (TODO describe row blocks).

The turbine jobs write RowBlocks to disk, replicating them over multiple locations (TODO describe LogDevice in more detail). Each log is associated with a "shard", simplifying management via Meta's internal tool called Shard Manager.

With the logs in a suitable format, they are ready to be queried. In order to make the logs available for querying, machines in the fleet called "leafs" replicate them locally. Each leaf machine is assigned shards to read (TODO link shard manager paper). The reason that leafs are assigned shards is that this allows for scaling - if there are more reads headed to any single shard, shard manager will instruct more leaf nodes to maintain a copy of it, spreading the reads out. Shard manager also handles data-management tasks like removing shards of datasets that should no longer be stored according to a configured retention policy.

### Remote Backup and Compaction

When new data enters the system, the ingestion process adds new entries to the LogDevice. From there, leaf nodes tail these entries in order to achieve near-realtime data availability. Given that the LogDevice is a fixed size, eventually data ages out of the LogDevice. At this point, leafs still want to access the underlying entries. To solve this problem, the _Backup Compaction Service (BCS)_ periodically reads data from the LogDevice, combines and compresses multiple blocks, then writes the output to a blob storage system. After writing the compressed data to blob storage, _BCS_ writes back a notification messasge to the LogDevice, indicating that after the specified entry it should read entries from blob storage, and not the LogDevice itself.

TODO figure 4

This process increases storage effiency (due to the compression technique), while lowering disk IO (to read the same amount of data, Kraken leaf nodes can perorm fewer disk accesses due to the larger individual size)

### Read Path

When a user issues a query for data stored in Kraken, a _root node_ executes the query, parallelizing it across the machines storing the partitions of the data they query accesses. The paper mentions that this "query architecture is largely retained from legacy Scuba", and this patten seems to be very similar to the architecture described by Monarch! TODO research if the original Scuba paper talks about the architecture.

When executing the query, Kraken also evaluates whether it needs to access data that is no longer stored in the core system (referred to being "out of retention"). While Kraken is able to store significantly more data than its predecessor, it still has limits. To solve this problem, it abstracts away accessing "out of retention" data stored in a separate, data warehouse-like structure.

## How is the research evaluated?

Kraken is an at-scale system, and the paper describes the productionization of the system as well as its performance when launched to users.

#### Productionaization

The paper talk about migrating from the original system to its current incarnation with minimal impact on users. While deploying the new infrastructure on its own posed little problem, the migration focused on performance, moving the underlying data and testing that the new system worked.

One main challenge that the team faced with performance was the switch to a model where globally-distributed deployment was performing cross-region operations (like on the ingestion path writing RowBlocks to LogDevices). The team addressed this problem by introducing batching, causing the latency overhead of cross-region operations to fewer times.

Moving the underlying data proceeded in several steps. First, the new tailer deployment was turned on for a single deployment of Scuba, and the tailers began writing data for both the new Kraken deployment and the old Scuba deployment. For historical data, the migration was a bit more complicated. Copying the historical dataset for a Scuba deployment would potentially have duplicate data if care wasn't taken (as the historical data written by the old Scuba system would have some overlap with the data written by the new system, unless the cutover between the new and old datasets was performed perfectly seamlessly). The authors implemented a labeling process such that the copying process could differentiate between new and old blocks.

Lastly, a concern of switching over to the new system was how it would perform at scale. To test this, the paper discusses conducting drain tests that rebalanced shards across different datacenters while monitoring performance and ability to adapt. Additionally, the paper used chaos testing to force failure in different components of the system, then watch its recovery. TODO link to chaos testing papers.

#### Experiments

To understand the performance of the new system, the paper considers query latency, ingestion performance, and recovery under failure conditions.

When measuring query latency, the paper looks at production datasets of different sizes and characteristics. Overall latency decreased between Kraken and Scuba deployments - the authors argue that this is because the nature of Kraken is such that the system knows definitely which shards it needs to query in order to respond to queries. As a result, there is lower tail latency because the engine must wait for fewer partitions to respond. Another advantage of querying fewer partitions for data is lower network overhead.

TODO Table 1

TODO Figure 5
TODO Figure 6

In the new version of the system, ingestion latency is also significantly decreased. The impact of lowering this metric is a better experience for users (who are relying on up to date logs in order to perform queries). The paper doesn't attribute any specific factor to lowering ingestion latency.

TODO Table 2

Lastly, the paper injects failures into the system (in particular impacting leaf nodes), and measures the number of shards available. Shard availability is a proxy for the ability to query data in the system, as shards map to individual logs. After eliminating 10% of the shards in a deployment, Kraken is able to recover to the baseline within 3 hours - the paper doesn't note whether they would be able to decrease this recovery time by taking action (potentially scaling capacity).

TODO Figure 7

## Conclusion

Kraken is a new iteration of tool used by many across Meta. It is similar in many respects to existing databases like Druid (TODO covered in a previous paper review). While I was familiar with several of the databases mentioned in the paper, I think that this paper is novel in that it describes the reasoning behind making different tradeoffs, in particular after learning from a previous system deployed internally at scale. Another factor of the paper I thoroughly enjoyed is learning about how the system was built on other Meta-internal projects (or at least some of them were open-sourced). Oftentimes papers elide the underlying implementation of the systems they are relying upon, but that is not true in this case!