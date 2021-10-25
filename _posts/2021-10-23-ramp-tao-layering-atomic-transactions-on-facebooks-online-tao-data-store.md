---
layout: post
title: "RAMP-TAO: Layering Atomic Transactions on Facebook’s Online TAO Data Store"
categories:
---

_The papers over the next few weeks will be from [SOSP](https://sosp2021.mpi-sws.org/), which is taking place October 26-29th, 2021. As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://www.getrevue.co/profile/systems-weekly), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

[RAMP-TAO: Layering Atomic Transactions on Facebook’s Online TAO Data Store](/assets/papers/ramp-tao.pdf)

This is the second in a two part series on TAO, Facebook's eventually-consistent{% sidenote 'ec' "I like [this description](https://www.allthingsdistributed.com/2008/12/eventually_consistent.html) of what eventual consistency means from Werner Vogels, Amazon's CTO."%} graph datastore. The [first part](/2021/10/13/tao-facebooks-distributed-data-store-for-the-social-graph.html) provides background on the system. This part (the second in the series) focuses on TAO-related research published at this year's VLDB - [RAMP-TAO: Layering Atomic Transactions on Facebook’s Online TAO Data Store](https://www.vldb.org/pvldb/vol14/p3014-cheng.pdf). 

The paper on RAMP-TAO describes the design and implementation of transactional semantics on top of the existing large scale distributed system, which "serves over ten billion reads and tens of millions of writes per second on a changing data set of many petabytes". This work is motivated by the difficulties that a lack of transactions poses for both internal application developers and external users. 

Adding transactional semantics to the existing system was made more difficult by other external engineering requirements - applications should be able gradually migrate to the new functionality and any new approach should have limited impact on the performance of existing applications. In building their solution, the authors adapt an existing protocol, called _RAMP_{% sidenote 'ramp' "While I give some background on RAMP further on in this paper review, [Peter Bailis](http://www.bailis.org/blog/scalable-atomic-visibility-with-ramp-transactions/) (an author on the RAMP and RAMP-TAO papers) and [The Morning Paper](https://blog.acolyer.org/2015/03/27/scalable-atomic-visibility-with-ramp-transactions/) both have great overviews." %}, to TAO's unique needs.

## TAO Background

This section provides a brief background on TAO - feel free to skip to the next section if you have either read [last week's paper review](/2021/10/13/tao-facebooks-distributed-data-store-for-the-social-graph.html), or the original TAO paper is fresh in your mind. TAO is an eventually consistent datastore that represents Facebook's graph data using two database models - associations (edges) and objects (nodes). 

To respond to the read-heavy demands placed on the system, the infrastructure is divided into two layers - the storage layer (MySQL databases which store the backing data) and the cache layer (which stores query results). The data in the storage layer is divided into many _shards_, and there are many copies of any given shard. Shards are kept in sync with leader/follower replication. 

Reads are first sent to the cache layer, which aims to serve as many queries as possible via cache hits. On a cache miss, the cache is updated with data from the storage layer. Writes are forwarded to the leader for a shard, and eventually replicated to followers - as seen in [other papers](https://research.fb.com/publications/wormhole-reliable-pub-sub-to-support-geo-replicated-internet-services/), Facebook invests significant engineering effort into the technology that handles this replication with low latency and high availability. 

## What are the paper's contributions?

The RAMP-TAO paper makes four main contributions. It explains the need for transactional semantics in TAO, quantifies the problem's impact, provides an implementation that fits the unique engineering constraints (which are covered in future sections), and demonstrates the feasability of the implementation with benchmarks. 

## Motivation

The paper begins by discussing why transactional semantics matter in TAO, then provides examples of how application developers have worked around their omission from the original design.

### Example problems

The lack of transactional semantics in TAO allows two types of problems to crop up: _partially successful writes_ and _fractured reads_. 

If writes are not batched together in transactions, it is possible for some of them to succeed and others to fail (_partially successful writes_), resulting in an incorrect state of the system (as evidenced by the figure below). 

{% maincolumn 'assets/ramp-tao/partially-successful-writes.png' '' %}

A _fractured read_ is "a read result that captures partial transactional updates", causing an inconsistent state to be returned to an application. _Fractured reads_ happen because of a combination of TAO's eventual consistency and lack of transactional semantics - writes to different shards are replicated independently. Eventually all of the writes will be reflected in a copy of the dataset receiving these updates. In the meantime, it is possible for only some of the writes to be reflected in the dataset. 

{% maincolumn 'assets/ramp-tao/fractured-read.png' '' %}

To address these two problems, the authors aruge that TAO must fulfill two guarantees:

- _Failure atomicity_ addresses _partially successful writes_ by ensuring "either all or none of the items in a write transaction are persisted."
- _Atomic visibility_ addresses _fractured reads_ by ensuring "a property that guarantees that either all or none of any transaction’s updates are visible to other transactions."{% sidenote 'stale' "As we will see later on in the paper review, it is preferable that TAO serves stale (rather than incorrect) data." %} 

### Existing failure atomicity solutions in TAO

The paper notes three existing approaches used to address _failure atomicity_ for applications built on TAO:  _single-shard MultiWrites_, _cross-shard transactions_, and _background repair_.

_Single-shard MultiWrites_ allows an application to perform many writes to the same shard (each shard of the data in TAO is stored as an individual database), meaning that this approach is able to use "MySQL transactions and their ACID properties" to ensure that all writes succeed or none of them do. There are several downsides including (but not limited to) hotspotting{% sidenote 'hotspotting' "If an application uses this approach, it will send many writes to a single machine/shard, which also could cause the shard to be larger than it would be otherwise." %} and the requirement that applications structure their schema/code to leverage the approach{% sidenote 'migrating' "If a paper isn't architected with this approach in mind, the paper notes that migrating an already-deployed application to use _single-shard MultiWrites_ at scale is difficult." %}.

_Cross-shard transactions_ allow writes to be executed across multiple shards using a two-phase commit protocol (a.k.a 2PC){% sidenote '2pc' "For more on 2PC, I highly recommend [this article](https://www.the-paper-trail.org/post/2008-11-27-consensus-protocols-two-phase-commit/) from [Henry Robinson](https://twitter.com/henryr)." %} to roll back or restart transactions as needed. While this approach ensures that writes are _failure atomic_ (all writes succeed or none of them do), it does not provide _atomic visibility_ ("all of a transactions updates are visible or none of them are"), as the writes from a stalled transaction will be partially visible.

The last approach is _background repair_. Certain entities in the database, like edges for which there will always be a complement (called bidirectional associations), can be automatically checked to ensure that both edges exist. Unfortunately, this technique is limited to a subset of all of the entities stored in TAO, as this property is not universal.

## Measuring failure

To determine the engineering requirements facing an implementation of transactional semantics in TAO, the paper evaluates how frequently and for how long _fractured reads_ persist. The paper doesn't dig as much into quantifying write-failures - while _failure atomicity_ is a property that the system should have, _cross-shard transactions_ roughly fill the requirement. Even so, _cross-shard transactions_ are still susceptible to _atomic visibility_ violations where some (but not all) of the writes from an in-progress transaction are visible to applications using TAO.

The results from the measurement study indicate that 1 in 1,500 transactions violate _atomic visibility_, noting that:

> 45% of these fractured reads last for only a short period of time (i.e., naïvely retrying within a few seconds resolves these anomalies). After a closer look, these short-lasting anomalies occur when read and write transactions begin within 500 ms of each other. For these atomic visibility violations, their corresponding write transactions were all successful. 

For the rest of the violations (those that are not fixed within 500ms):

> these atomic visibility violations could not be fixed within a short retry window and last up to 13 seconds. For this set of anomalies, their overlapping write transactions needed to undergo the 2PC failure recovery process, during which read anomalies persisted.

The paper's authors argue that atomic visibility violations pose difficulties for engineers building applications with TAO, as "any decrease in write availability (e.g., from service deployment, data center maintenance, to outages) increases the probability that write transactions will stall, leading in turn to more read anomalies".

## Design 

Following the measurement study, the paper pivots to discussing the design of a read API that provides _atomic visibility_ for TAO - there are three components to the design:

- Choosing an isolation model{% sidenote 'isolation model' "Isolation models define how transactions observe the impact of other running/completed transactions - related blog post from FaunaDB [here](https://fauna.com/blog/introduction-to-transaction-isolation-levels). This page from [Jepsen](https://jepsen.io/consistency) discusses the different, but related topic of distributed system consistency models."%}
- Constraints posed by the existing TAO infrastructure.
- The protocol that clients will use to eliminate _atomic visibility violations_.

### Isolation model

The paper considers whether a Snapshot Isolation, Read Atomic isolation, or Read Uncommitted isolation model best solve the requirement of eliminating _atomic visibility_ violations (while maintaining the performance of the existing read-heavy workloads served by TAO). The authors choose Read Atomic isolation as it does not introduce unncessary features at the cost of performance as Snapshot Isolation does{% sidenote 'snapshot' "Snapshot Isolation provides point-in-time snapshots of a database useful for analytical queries, which TAO is not focused on supporting."%}, nor does it allow fractured reads as Read Committed does{% sidenote 'rc' 'Read Committed "prevents access to uncommitted or intermediate versions of data", but it is possible for TAO transactions to be committed, but not replicated.' %}.

### Design constraints

To implement Read Atomic isolation, the authors turn to the RAMP protocol{% sidenote 'ramp' "While I give some background on RAMP, [Peter Bailis](http://www.bailis.org/blog/scalable-atomic-visibility-with-ramp-transactions/) (an author on the RAMP and RAMP-TAO papers) and [The Morning Paper](https://blog.acolyer.org/2015/03/27/scalable-atomic-visibility-with-ramp-transactions/) both have great overviews." %} (short for _Read Atomic Multiple Partition_) - several key ideas in RAMP fit well within the paradigm that TAO uses (where there are multiple partitions of the data) and can achieve _Read Atomic_ isolation. 

The RAMP read protocol works in two phases:

> In the first round, RAMP sends out read requests for all data items and detects nonatomic reads{% sidenote 'nonatomic' "Which could happen if only part of another transaction's writes were visible." %}. In the second round, the algorithm explicitly repairs these reads by fetching any missing versions. RAMP writers use a modified two-phase commit protocol that requires metadata to be attached to each update, similar to the mechanism used by cross-shard write transactions on TAO. 

Unfortunately, the original RAMP implementation can not be directly implemented in TAO, as the original paper operates with different assumptions:

- RAMP assumes that all transactions in the system are using the protocol, but it is infeasible to have all TAO clients support the new functionality on day one. In the meantime, unupgraded clients shouldn't incur the protocol's overhead.
- RAMP maintains metadata for each item, but doesn't consider replicating that data to increase availability{% sidenote 'metadata' "There are many replicas of each shard in TAO, so the metadata has to be copied for every shard."%}, like TAO will need to.
- RAMP assumes multiple versions of data is available, although this is not true - TAO maintains a single version for each row.

While the solutions to the first two challenges are non-trivial, they are relatively more straightforward - the first is addressed by gradually rolling out the functionality to applications, while the problem of metadata size is solved by applying specific structuring to MySQL tables. The next section of this paper review focuses on how TAO addresses the third challenge of "multiversioning". 

## Implementation

RAMP-TAO adapts the existing RAMP{% sidenote 'ramp' "Specifically, the paper adapts one of three RAMP variants, RAMP-FAST. Each RAMP variant TODO" %} protocol to fit the specifics of Facebook's use case. This section describes a critical piece of Facebook infrastructure (called the _RefillLibrary_) used in TAO's implementation, as well as how RAMP-TAO works.

### The RefillLibrary

First, RAMP-TAO uses an existing piece of Facebook infrastructure called the _RefillLibrary_ to add support for "limited multiversioning" - "the RefillLibrary is a metadata buffer recording recent writes within TAO, and it stores approximately 3 minutes of writes from all regions". By including additional metadata about whether items in the buffer were impacted by write transactions, RAMP-TAO can ensure that the system doesn't violate _atomic visibility_. 

{% maincolumn 'assets/ramp-tao/refill.png' '' %}

When a read happens, TAO first checks whether the items being read are in the _RefillLibrary_. If any items are in the _RefillLibrary_ and are marked as being written in a transaction, TAO returns metadata about the write to the caller. The caller in turn uses this metadata to perform logic that ensure _atomic visibility_ (described in the next section). If there is not a corresponding element in the _RefillLibrary_ for an item, "there are two possibilities: either it has been evicted (aged out) or it was updated too recently and has not been replicated to the local cache." 

To determine which situation applies, TAO compares the timestamp of the oldest item in the _RefillLibrary_ to the timestamps of the items being read.

If the timestamps for all read items are older than the oldest timestamp in the _RefillLibrary_, it is safe to assume replication is complete - writes are evicted after 3 minutes, and based on the measurement study there are few replication issues that last that long. On the other hand, RAMP-TAO needs to perform additional work if timestamps from read items are greater than the oldest timestamp in the _RefillLibrary_ (in other words, still within the 3 minute range), and there are no entries in the _RefillLibrary_ for those items. This situation occurs if a write has not been replicated to the given location. To resolve this case, TAO performs a database request, and returns the most recent version stored in the database to the client (who may use the data to ensure _atomic visibility_, as discussed in the next section).

### The RAMP-TAO Protocol

A primary goal of the RAMP-TAO protocol is ensuring _atomic visibility_ ("a property that guarantees that either all or none of any transaction’s updates are visible to other transactions"). At the same time, RAMP-TAO aims to offer comparable performance for existing applications that migrate to the new technology. Existing applications that don't make use of transactional semantics parallelize requests to TAO and use whatever the database returns, even if the result reflects state from an in-progress transaction. In contrast, RAMP-TAO resolves situations where data from in-progress transactions is returned to applications.

There are two primary paths that read requests in RAMP-TAO take: the _fast path_ and the _slow path_.

The _fast path_ happens in one round - the clients issue parallel read requests, and the returned data doesn't reflect the partial result of an in-progress transaction{% sidenote 'hooray' "Hooray!"%}.

{% maincolumn 'assets/ramp-tao/fast.png' '' %}

In contrast, RAMP-TAO follows the _slow path_ when data is returned to the client that reflects an in-progress write transaction. In this situation, TAO reissues read requests to resolve the _atomic visibility violation_. One way that violations are resolved on the slow path is by reissuing a request to fetch an older version of data - TAO applications are tolerant to serving stale, but correct, data.

{% maincolumn 'assets/ramp-tao/slow.png' '' %}

## Performance

To evaluate the prototype system's performance, the authors evaluate the performance of the protocol:

> Our prototype serves over 99.93% of read transactions in one round of communication. Even when a subsequent round is necessary, the performance impact is small and bounded to under 114ms in the 99𝑡ℎ percentile (Figure 12). Our tail latency is within the range of TAO’s P99 read latency of 105ms for a similar workload. We note that these are the worst-case results for RAMP-TAO because the prototype currently requires multiple round trips to the database for transaction metadata. Once the changes to the RefillLibrary are in place, the large majority of the read transactions can be directly served with data in this buffer and will take no longer than a typical TAO read.

## Conclusion

While RAMP-TAO is still in development (and will require further changes to both applications and Facebook infrastructure), it is exciting to see the adaptation of existing systems to different constraints - unlike systems built from scratch, RAMP-TAO also needed to balance unique technical considerations like permitting gradual adoption. I enjoyed the RAMP-TAO paper as it not only solves a difficult technical problem, but also clearly outlines the thinking and tradeoffs behind the design. 

As always, feel free to reach out with feedback on [Twitter](https://twitter.com/micahlerner)!