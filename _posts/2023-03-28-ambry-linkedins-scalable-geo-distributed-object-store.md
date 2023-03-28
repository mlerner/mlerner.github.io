---
layout: post
title: "Ambry: LinkedIn’s Scalable Geo-Distributed Object Store"
intro: These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions!
categories:
---

[Ambry: LinkedIn’s Scalable Geo-Distributed Object Store](/assets/pdf/ambry.pdf)

## What is the research?

Blob stores are used by companies across industry (including [Meta's f4](https://www.usenix.org/system/files/conference/osdi14/osdi14-paper-muralidhar.pdf), [Twitter](https://blog.twitter.com/engineering/en_us/a/2012/blobstore-twitter-s-in-house-photo-storage-system), and [Amazon](https://assets.amazon.science/77/5e/4a7c238f4ce890efdc325df83263/using-lightweight-formal-methods-to-validate-a-key-value-storage-node-in-amazon-s3-2.pdf)) to store large objects, like photos and videos. This paper focuses on Ambry from LinkedIn which, unlike other implementations, is [open source](https://github.com/linkedin/ambry).

Ambry aims to provide low latency blob store operations, with high throughput, using globally distributed storage and compute resources. At the time of the paper's publication in 2016, LinkedIn had hundreds of millions of users, and served more than 120 TB every day{% sidenote '5tb' "Sharing the required [I only want to serve 5TBs](https://www.youtube.com/watch?v=3t6L-FlfeaI) reference." %}. To reach this scale, the team had to solve several challenges including wide variance in object sizes, rapid growth, and unpredictable read workloads.

## How does the system work?

### Blobs and Partitions

Ambry's core abstraction is the _blob_, an immutable structure for storing data. Each blob is assigned to a _partition_ on disk and is referenced via a _blob ID_. Users of the system interact with blobs by performing `put`, `get`, and `delete` operations. Ambry represents `put` and `delete` operations to blobs as entries in an append-only log for their assigned partition.

{% maincolumn 'assets/ambry/figure2.png' '' %}

Partitioning data allows Ambry to scale - as users add more data to the system, it can add more partitions. By default, a new partition is _read-write_ (meaning that it accepts both `put`, `get`, and `delete` traffic). As a partition nears capacity, it transitions into _read_, meaning that it no longer supports storing new blobs via `put` operations. Traffic to the system tends to be targeted at more recent content, placing higher load on _read-write_ partitions.

### Architecture

To provide scalable read and write access to blobs, Ambry uses three high-level components: _Cluster Managers_, the _Frontend Layer_, and _Datanodes_.

{% maincolumn 'assets/ambry/figure1.png' '' %}

#### Cluster Managers

_Cluster managers_ make decisions about how data is stored in the system across geo-distributed data centers, as well as storing the state of the cluster{% sidenote 'zk' "The paper mentions that state is mostly stored in [Zookeeper](https://zookeeper.apache.org/)."%}. For example, they store the _logical layout_ of an Ambry deployment, covering whether a partition is read-write or read-only, as well as the partition placement on disks in data centers.

{% maincolumn 'assets/ambry/table2.png' '' %}

#### The Frontend Layer

The _Frontend Layer_ is made up of stateless servers, each pulling configuration from _Cluster Managers_. These servers primarily respond to user requests, and their stateless nature simplifies scaling - arbitrary numbers of new servers can be added to the frontend layer in response to increasing load. Beyond handling requests, the _Frontend Layer_ also performs security checks and logs data to LinkedIn's change-data capture system{% sidenote 'cdc' "[Change data capture](https://www.oreilly.com/library/view/streaming-change-data/9781492032526/ch01.html) or [event sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) is a way of logging state changes for consumption/replay by downstream services for arbitrary purposes, like replicating to a secondary data source."%}.

The _Frontend Layer_ routes requests to _Datanodes_ by combining the state supplied by _Cluster Managers_ with a routing library that handles advanced features like:

- Fetching large "chunked" files from multiple partitions and combining the results (each chunk is assigned an ID, and mapped to a uniquely identified blob stored in a partition).
- Detecting failures when fetching certain partitions from _datanodes_.
- Following a retry policy to fetch data on failure.

{% maincolumn 'assets/ambry/figure4.png' '' %}
{% maincolumn 'assets/ambry/figure5.png' '' %}

#### Datanodes

_Datanodes_ enable low-latency access to content stored in memory (or on disk) by using several performance enhancements. To enable fast access to blobs, datanodes store an index mapping blob IDs to their offset in the storage medium. As new operations update the state of a blob (potentially deleting it), datanodes update this index. When responding to incoming queries, the _datanode_ references the index to find the state of a blob.

{% maincolumn 'assets/ambry/figure6.png' '' %}

To maximize the number of blobs stored in disk cache, Ambry also optimizes how the index itself is stored, paging out older entries in the index to disk{% sidenote 'sstables' "The paper also references SSTables, used by systems like [Cassandra](https://cassandra.apache.org/doc/latest/cassandra/architecture/storage_engine.html) to store and compact indexes."%}. Datanodes also rely on other tricks, like zero copy operations{% sidenote 'zc' "Which limit unnecessary memory operations, as discussed in a previous paper review of [Breakfast of Champions: Towards Zero-Copy Serialization with NIC Scatter-Gather](https://www.micahlerner.com/2021/07/07/breakfast-of-champions-towards-zero-copy-serialization-with-nic-scatter-gather.html)."%} and batching writes to disk{% sidenote 'batch' "Discussed in the paper review of [Kangaroo: Caching Billions of Tiny Objects on Flash](https://www.micahlerner.com/2021/12/11/kangaroo-caching-billions-of-tiny-objects-on-flash.html)."%}.

### Operations

When the _Frontend Layer_ receives an operation from a client, the server's _routing library_ helps with contacting the correct partitions:

> In the put operation, the partition is chosen randomly (for data balancing purposes), and in the get/delete operation the partition is extracted from the blob id.

{% maincolumn 'assets/ambry/figure3.png' '' %}

For `put` operations, Ambry can be configured to replicate synchronously (which makes sure that the blob appears on multiple datanodes before returning), or asynchronously - synchronous replication safeguards against data loss, but introduces higher latency on the write path.

If set up in an asynchronous configuration, replicas of a partition exchange _journals_ storing blobs and their offsets in storage. After reconciling these journals, they transfer blobs between one another. As far as I understand, the implementation seems like a gossip protocol{% sidenote 'gossip' "Gossip protocols are discussed in more depth [here](http://highscalability.com/blog/2011/11/14/using-gossip-protocols-for-failure-detection-monitoring-mess.html). There is also an interesting paper from Werner Vogels (CTO of Amazon) on the topic [here](https://dl.acm.org/doi/10.1145/774763.774784)."%}.

{% maincolumn 'assets/ambry/figure7.png' '' %}

## How is the research evaluated?

The paper evaluates the research in two main areas{% sidenote 'lb' "The paper also includes an evaluation of load-balancing not from production data, which I didn't find to be particularly useful - it would be great if there was updated data on this topic from the project!"%}: _throughput and latency_, and _geo-distributed operations_.

To test the system's throughput and latency (critical to low-cost serving of user-facing traffic at scale), the authors send read and write traffic of differently sized objects to an Ambry deployment. The system is able to provide near-equivalent performance to reads/writes of larger objects, but tops out at a lower performance limit with many small reads/writes. The paper notes that this is likely due to large numbers of disk seeks (and a similarly shaped workload is unlikely to happen in a real deployment).

{% maincolumn 'assets/ambry/figure8.png' '' %}
{% maincolumn 'assets/ambry/figure9.png' '' %}

To evaluate geo-distributed operations and replication, the paper measures the bandwidth and time it requires, finding that both are near-negligble:

- In 85% of cases, replication lag was non-existent.
- Bandwidth for replicating blobs was small (10MB/s), but higher for inter-datacenter communication.

{% maincolumn 'assets/ambry/figure14-15.png' '' %}

## Conclusion

Unlike other blobstores{% sidenote 'meta' "I haven't written about the other blob storage systems from Meta and Twitter, but would like to soon!" %}, Ambry is unique in existing as an open source implementation. The system also effectively makes tradeoffs at scale around replication using a gossip-like protocol. The paper also documents some of the challenges with load balancing its workload, a problem area that other teams{% sidenote 'shard' "See my previous paper review on [Shard Manager](https://www.micahlerner.com/2022/01/08/shard-manager-a-generic-shard-management-framework-for-geo-distributed-applications.html)."%} tackled since the original publish date of 2016. Lastly, it was useful to reflect on what Ambry _doesn't_ have - it's key-value based approach to interacting with blobs doesn't support file-system like capabilities, posing more of a burden on the user of the system (who must manage metadata and relationships between entities themselves).