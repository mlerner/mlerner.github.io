---
layout: post
title: "Slicer: Auto-Sharding for Datacenter Applications"
categories:
---

[Slicer: Auto-Sharding for Datacenter Applications](TODO)

## What is the research and why does it matter?

Slicer is a system for deploying sharded services at Google, similar to those deployed at Meta with Shard Manager (TODO reference). The technique of sharding services often involves assigning a subset of a dataset to tasks deployed in cloud infrastructure - for example, the Slicer paper references giving assigning languages for text to speech to a set of tasks, so that not all tasks need to load the models required to perform the function.

Slicer's goal is providing a simple API that services that want to adopt sharding can use. This idea of providing a common interface that teams could adopt had significant performance benefits (TODO describe why), while eliminating custom implementations of sharding, which represented technical debt.

## How does the system work?

### Design

Slicer splits the responsibilities of a sharded service across tasks in a datacenter deployment. Sharding operates at the "key" level and each application can decide what key to use (e.g. user id, language in the case of the translation application).

There are three main components of the Slicer design:
- Centralized Slicer Service which functions as a coordination layer
- Slicelet, which runs on the sharded service itself
- Clerk, a library embedded in clients of a sharded service

TODO figure 2

The centralized slicer service generates an assignment mapping key ranges (“slices”) to tasks", then makes this dataset available to consumers (notably the clients and servers of the sharded system). The keys are hashed and the centralized slicers service job is to make sure that keys are loadbalanced across tasks, preventing "hot spotting". By default, a key is assigned to a single task, but this is configurable by users of the system.

To integrate with Slicer, systems implement the _Slicelet_ interface. This allows the service to do things like responding when key assignment changes - for example, fetching data from a backing datastore. Services also have the flexibility to respond to requests associated with keys that they don't handle if they so choose (although why requests are misrouted is confusing)

A consumer the sharded service implements the Clerk interface, which allows it do discover which tasks it should talk to for a given RPC. There are also interactions between a service and other load balancers (for example, the load balancer will select a datacenter, but the task to talk to in that datacenter are up to the individual clien)

TODO figure 3

The paper talks about three main categories of use cases it supports: in-memory caches, in-memory store, and aggregation. For the first use case, the paper talks about an applications which maintain in-memory caches to speed up performance - for example, a meeting scheduler which has a per user cache and a "crawl manager" which extracts and stores metadata about a URL. Second, the paper talks about in-memory store where the system loads data from a backing datasource - the speech recognition example discussed at the beginning is one of these. Second, the paper talks about in-memory store where the system loads data from a backing datasource - the speech recognition example discussed at the beginning is one of these.

### Implementation

Slicer has two main components: the assigner and distributors.

TODO figure 5

The role of the assigner is to assign shards to tasks. It makes its decision by taking in signals on job size, health, and load. For reliability and scalability, Slicer deploys multiple assigners in datacenters around the world. This adds complexity if multiple assigners are operating on the same application - which assigner is making the final decision?. The system handles this complexity using something akin to optimistic concurrency control.

Distributors handle propagating assignments to clients of the sharded system and the servers. There is complexity in doing this because for large jobs, the assignments can be quite large:

> Distribution is a pull model: a subscriber asks a Distributor for a job’s assignment; if the Distributor doesn’t have it, the distrubutor asks the Assigner, which generates and distributes the assignment. Each Clerk and Slicelet library maintains a long-lived stream with the Distributor service using Google’s standard load balancer service, which routes its stream to the closest available instance.

The paper also talks about alternative architectures! Ror example, peer to peer sharing of assignments. The reason they don't do this is to avoid having to expose users of the system to additional complexity.

The paper also talks about the fault tolerance of the system - which appears to be "fail open". Slicer aims to reduce risk by introducing "backup distributors" which read assignments directly from storage, rather than potentially computing new assignments. Additionally, the components of the system are globally distributed, and in some cases situated in a way where they can function even if the WAN (which connects) datacenters goes down.

Lastly, Slicer implements load balancing which can handle key imbalance and adjust over time by either - "adding or removing redundant tasks for a key or by reassigning keys from one task to another". Furthermore, the system will dynamically reshard through an algorithm it calls "weighted move" in the paper - the goal of the algorithm is to reduce load imbalance taking into account the impact of moving shards between tasks.  The process of resharding involves splitting up ranges of keys if they are particularly hot, colocating "hot slices" with "cold slices"

## How is the research evaluated?

The paper evaluates Slicer's reliablity, load balancing capabilities, and scalability using both produciton data experimental configurations that force the system into certain states.

In production, Slicer is able to successfully to select tasks for a shard for RPC requests 99.98% of the time. Of the RPCs that were sent, 0.004% were misrouted (indicating a disconnect between the selected shard and the production state).

To evaluate production load balancing, the paper shares data on the number of requests handled by a task, movement of the keyspace, and load per task.

TODO figure 6
TODO figure 7

Additionally, the paper compares load balancing for static allocations of the keyspace over tasks, versus Slicer's dynamic adjustments, finding that Slicer succeeds at reducing both max and mean load for tasks.

TODO figure 9

To evaluate the assigner, the paper looks at the time to distribute assignments around the system, finding that "95% of assignments reach subscribers within 2 s."

TODO figure 10

When an assigner fails, there is clear impact on load balancing, however, " if an Assigner fails, any other Assigner can pick up the slack. We configured a test job with two Assigners, killed the active one, and observed that the other became initialized 17.1 s later".

TODO figure 12

Lastly, Slicer is able to respond to changing load quickly on shards. TODO describe more

TODO figure 13


## Conclusion

One aspect of the paper I enjoyed was its discussion of design tradeoffs. For example, they don't use consistent hashing to generate assignments because:

> A variant of consistent hashing [22] with load balancing support [10] yielded both unsatisfactory load balancing and large, fragmented assignments. We refer to this scheme as load-aware consistent hashing. Some applications had too few slice keys (tens to hundreds per task) for consistent hashing to result in good statistical load balancing.

While Slicer has many commonolities with systems that followed it, there are a few key differences with systems like Shard Manager - notably Slicer has the framework deciding shards, where in ShardManager, the application code decides the shards. The ShardManager paper makes these case for the latter as it provides more flexibility in which types of applications are supported. While Slicer sharding uses UUIDs (to reduce hotspotting), having non-contiguous data in shards makes "prefix scans" more difficult.
