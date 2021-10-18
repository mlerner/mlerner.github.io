---
layout: post
title: "TAO: Facebook’s Distributed Data Store for the Social Graph"
categories:
---

_The papers over the next few weeks will be from (or related to) research from [VLDB 2021](https://vldb.org/2021/?info-research-papers). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://tinyletter.com/micahlerner/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

[TAO: Facebook’s Distributed Data Store for the Social Graph](https://www.usenix.org/system/files/conference/atc13/atc13-bronson.pdf)

This is the first in a two part series on TAO{% sidenote 'tao' 'TAO stands for "The Associations and Objects" - associations are the edges in graph, and objects are the nodes.'%}, Facebook's read-optimized, eventually-consistent graph database. The first part focuses on the original TAO paper, describing the motivation for building the system, it's architecture, and engineering lessons learned along the way. 

The second part focuses on TAO-related research published at this year's VLDB - [RAMP-TAO: Layering Atomic Transactions on Facebook’s Online TAO Data Store](https://www.vldb.org/pvldb/vol14/p3014-cheng.pdf). The new paper describes the design and implementation of transactions on top of the existing large scale distributed system (a task made more difficult by the requirement that applications should gradually migrate to the new functionality and the changes to support transactions should have limited impact on the performance of existing applications).

## What are the paper's contributions?

The original TAO paper makes three contributions - characterizing and motivating a graph database implementation suited for Facebook's read-heavy traffic, providing a data model and developer API for the aforementioned database, and describing the architecture that allowed the database to scale. 

## Motivation

The paper begins with a section describing the motivation for TAO's initial development. When Facebook was originally developed, MySQL was used as the datastore for the graph. As the site scaled, a memcache layer was added in front of the MySQL databases, to lighten the load. 

While inserting memcache into the stack worked for some period of time, the paper cites three main problems with the implementation: _inefficient edge lists_, _distributed control logic_, and _expensive read-after-write consistency_.

Application developers within Facebook used _edge-lists_ to represent aggregations of the information in the graph - for example, a list of the friendships a user has (each friendship is an edge in the graph, and the users are the nodes). Unfortunately, maintaining these lists in memcache was inefficient - memcache is a simple key value store without support for lists, meaning that common list-related functionality (like that supported in [Redis](https://redis.io/topics/data-types#lists)) is inefficient. If a list needs to be updated (say for example, a friendship is deleted), the logic to update the list would be complicated (in particular, the part of the logic related to coordinating the update of the list across multiple copies of the same data across multiple data centers).

Control logic (in the context of Facebook's graph store architecture) means the ability to manipulate how the system is accessed. Before TAO was implemented, the graph data store had _distributed control logic_ - clients communciated directly with the memcache nodes, and there is not a single source of control that can gate client access to the system. This property makes it difficult to guard against misbehaving clients, making problems like [thundering herds](https://instagram-engineering.com/thundering-herds-promises-82191c8af57d) harder to prevent.

_Read-after-write consistency_ means that if a client writes data, then performs a read of the data, the client should see the result of the write that it performed. If a system doesn't have this property, users might be confused - "why did the like button they just pressed not register when they reloaded the page?". Ensuring read-after-write consistency was expensive and difficult for Facebook's memcache-based system, which used MySQL databases with master/slave replication to propagate database writes. While Facebook developed internal technology{% sidenote 'memcache' 'As described in my previous paper review, [Scaling Memcache at Facebook](https://www.micahlerner.com/2021/05/31/scaling-memcache-at-facebook.html).'%} to propagate writes between databases, existing systems that used the MySQL and memcache combo relied on forwarding reads for cache keys invalidated by a write to the leader database, increasing load and incurring potentially slow inter-regional communication. The goal of this new system is to avoid this overhead (with an approach described later in the paper).

## Data model and API

TAO is an eventually consistent{% sidenote 'werner' "For a description of eventual consistency (and related topics!), I highly recommend [this post](https://www.allthingsdistributed.com/2008/12/eventually_consistent.html) from Werner Vogels."%} read-optimized data store for the Facebook graph that stores two entities - _objects_ and _associations_ (the relationships between objects). Now we get to learn why the graph datastore is called TAO - the name is an abbreviation that stands for "The Associations and Objects".

As an example of how _objects_ and _associations_ are used to model data, consider two common social network functions - friendships between users and check-ins. Users in the database are stored as _objects_, and the relationship between users are _associations_. For a check-in, the user and the location they check in to are _objects_, and an _association_ exists between them to represent that the given user has checked into a given location. 

Objects and associations have different database representations: 

- Each _object_ in the database has an id and type.
- Each _association_ contains the ids of the objects connected by the given edge, as well as the type of the association (check-in, friendship, etc). Additionally, each association has a timestamp that is used for querying (described later in the paper review).

Key-value metadata can be associated with both objects and associations, although the possible keys, and value type are constrained by the type of the object or association.

{% maincolumn 'assets/tao-pt1/objects.png' '' %}

To provide access to this data, TAO provides three main APIs: the _Object API_, the _Association API_, and the _Association Querying API_. 

Two of the three (the _Object API_ and _Association API_) provide create, read, update, and delete operations for individual objects.

In contrast, the _Association Querying API_ provides an interface for performing common queries on the graph. The provided query methods allow application developers to fetch associations for a given object and type (potentially constraining by time range or the set of objects that the the association points), calculating the count of associations for an object, and providing pagination-like functionality. The paper provides example query patterns like fetching the "50 most recent comments on Alice’s checkin"  or “how many checkins at the GG Bridge?". Queries in this API return multiple associations, and call this type of result an _association list_. 

## Architecture

The architecture of TAO contains two layers, the _storage layer_ and the _caching layer_. 

### Storage Layer

The _storage layer_ (as the name suggests) persists graph data in MySQL{% sidenote 'mysql' "Facebook has invested a significant amount of resources in their MySQL deployments, as evidenced by their [MyRocks](https://engineering.fb.com/2016/08/31/core-data/myrocks-a-space-and-write-optimized-mysql-database/) storage engine and [other posts](https://engineering.fb.com/2021/07/22/data-infrastructure/mysql/) on their tech blog."%}. There are two key technical points to the storage layer: _shards_ and the _tables_ used to store the graph data itself.

The graph data is divided into _shards_ (represented as a MySQL database), and shards are mapped to one of many database servers. Objects and associations for a shard are stored in separate tables. 

### Cache Layer

The cache layer is optimized for read requests and stores query results in memory. There are three key ideas in the cache layer: _cache servers_, _cache tiers_, and _leader/follower tiers_.

Clients communicate read and write requests to _cache servers_. Each _cache server_ services requests for a set of shards in the _storage layer_, and caches objects, associatons, and the size of association lists (via the query patterns mentioned in the API section above). 

A _cache tier_ is a collection of _cache servers_ that can respond to requests for all shards - the number of cache servers in each tier is configurable, as is the mapping from request to cache server. 

_Cache tiers_ can be set up as _leaders_ or _followers_. Whether a cache tier is a _leader_ or a _follower_ impacts its behavior:

- _Follower tiers_ can serve read requests without communicating with the leader (although they forward read misses and write requests to the corresponding cache servers in the leader tier). 
- _Leader tiers_ communicate with the storage layer (by reading and writing to/from the database), as well as with _follower_ cache tiers. In the background, the _leader tier_ sends cache update messages to _follower tiers_ (resulting in the eventual consistency mentioned earlier on in this paper review).

## Scaling

To operate at large scale, TAO needed to extend beyond a single region. The system accomplishes this goal by using a master/slave configuration for each shard of the database.

{% maincolumn 'assets/tao-pt1/ms.png' '' %}

In the master/slave configuration, each shard has a single _leader_ cache tier and many _follower_ cache tiers. The data in the storage layer for each shard is replicated from the master region to slave regions asynchronously. 

A primary difference between the single region configuration described above and the multi-region configuration is the behavior of the _leader tier_ when it receives writes. In a single-region configuration, the leader tier always forwards writes to the _storage layer_. In contrast, the leader tier in a multi-region TAO configuration writes to the _storage layer_ only if the _leader tier_ is in the _master region_. If the _leader tier_ is not in the _master region_ (meaning it is in a slave region!), then the _leader tier_ needs to forward the write to the _master region_. Once the _master region_ acknowledges the write, the slave region updates its local cache with the result of the write.

## Conclusion

TAO is a graph database operating at immense scale. The system was built on the emerging needs of Facebook, and had limited support for transactions{% sidenote 'txns' "The paper mentions limited transaction-like behavior but does not provide significant details"%}. The next paper in the series discusses how transactions were added to the system, while maintaining performance for existing applications and providing an opt-in upgrade path for new applications. 

As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with any feedback or paper suggestions. Until next time