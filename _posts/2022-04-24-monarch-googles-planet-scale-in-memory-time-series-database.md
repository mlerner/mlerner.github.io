---
layout: post
title: "Monarch: Google’s Planet-Scale In-Memory Time Series Database"
intro: These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions!
hn: https://news.ycombinator.com/item?id=31379383
categories:
---

[Monarch: Google’s Planet-Scale In-Memory Time Series Database](https://research.google/pubs/pub50652/)

## What is the research?

Monarch is Google's system for storing time-series metrics{% sidenote 'timeseries' "Time-series data describes data points that occur over time. Storing and using this type of information is an [active area of research](https://paperswithcode.com/task/time-series) and [industry development](https://www.timescale.com/blog/what-the-heck-is-time-series-data-and-why-do-i-need-a-time-series-database-dcf3b1b18563/)." %}. Time series metrics{% sidenote 'o11ystack' "Metrics are one of the main components in an observability stack (among tracing, events, and logging). The paper [Towards Observability Data Management at Scale](https://people.csail.mit.edu/tatbul/publications/sigmod_record20.pdf) has more information on the other components of the stack."%} are used for alerting, graphing performance, and ad-hoc diagnosis of problems in production.

Monarch is not the first time series database, nor is it the first optimized for storing metrics{% sidenote 'tsdbs' "[InfluxDB](https://www.influxdata.com/), [TimescaleDB](https://www.timescale.com/), [Prometheus](https://prometheus.io/), and [Gorilla](https://www.vldb.org/pvldb/vol8/p1816-teller.pdf) are just a few of the existing time series databases." %}, but the system is unique for several reasons.

First, Monarch optimizes for availability - you wouldn't want a metrics system to be down before, during, or after a production incident, potentially lengthening the time to detection or resolution of an outage. One example of this tradeoff in practice is Monarch's choice to store data in (relatively) more expensive memory, rather than on persistent storage. This design choice limits dependence on external databases (increasing availability by limiting dependencies), but increases cost.

Second, Monarch chooses a _push-based_ approach to collecting metrics from external services. This is contrast to _pull-based_ systems like [Prometheus](https://www.vldb.org/pvldb/vol8/p1816-teller.pdf) and Borgmon ([Monarch's predecessor](https://sre.google/sre-book/practical-alerting/)){% sidenote 'pull' 'The paper notes that the pull-based approach, "Other existing metrics databases, like [Facebook Scuba](https://research.facebook.com/publications/scuba-diving-into-data-at-facebook/) also use a push-based approach.'%}. The paper notes several challenges with a _pull-based_ approach to gathering metrics, including that the monitoring system itself needs to implement complex functionality to ensure that relevant data are being collected.

## What are the paper's contributions?

The Monarch paper makes four main contributions:

- An architecture for a time-series database capable of operating at global scale
- A data model and query language for accessing metrics
- A three-part implementation, covering a collection pipeline for ingesting metrics, a query interface, and a configuration system
- An analysis of the system running that scale

## How does the system work?

### Architecture

To implement these features at a worldwide scale, Monarch contains _global_ and _zone_ components.

{% maincolumn 'assets/monarch/fig1.png' '' %}

_Global_ components handles optimal query execution, and store primary copies of global state (like configuration). In contrast, _Zone_ components are responsible for providing functionality for a subset of metrics data stored in the given area, and maintaining replicas of global state.

Dividing Monarch into _Global_ and _Zone_ components enables scaling and availability of the system. In the presence of availability issues with _global_ components, _zones_  can still operate independently. _Zones_ can also operate with stale data, highlighting the consistency tradeoff that Monarch makes in order to gain availability.

At the bottom level of the Monarch stack are _Leaf_ nodes that store metrics data in-memory (formatted as described in the next section on the data model). _Leaves_ respond to requests from other parts of the system in order to receive new data that needs to be stored, or return data in response to a query.

### Data Model

Monarch stores data in _tables_. _Tables_ are built from combinations of _schemas_, which describe data stored in the table (like column names and datatypes).

{% maincolumn 'assets/monarch/fig2.png' '' %}

There are two types of schemas:

- _Target schemas_, which "associate each time series with its source entity (or monitored entity), which is, for example, the process or the VM that generates the time series." Importantly, target schemas can be used to decide which _zone_ to store data in (as storing data near where it is generated limits network usage).
- _Metric schemas_, which store metrics metadata and other typed data (int64, boolean, double, string) in a structured format.

Schemas have two types of columns: _key columns_ and _value columns_. The former is used to query/filter data, while the latter is used for analysis.

### Query Language

The Monarch query language allows a user to fetch, filter, and process metrics data in a SQL-like language.

{% maincolumn 'assets/monarch/fig6-7.png' '' %}

The example query above uses `fetch` to get the data, `filter` to include matching metrics, `join` to combine two streams of metrics, and `group_by` to perform an aggregation on the metrics:

> [These] operations ... are a subset of the available operations, which also include the ability to choose the top n time series according to a value expression, aggregate values across time as well as across different time series, remap schemas and modify key and value columns, union input tables, and compute time series values with arbitrary expressions such as extracting percentiles from distribution values.

### Metric Collection

External services push metrics to leaf nodes by using "routers", of which there are two types:

- _Ingestion Routers_ receive requests at the global level, and determine which _zone_ or _zones_ the incoming data needs to be stored in. Metrics are routed for storage in a _zone_ based on several factors, like the origin of the data{% sidenote 'storage' "Storing the data close to its origin limits network traffic."%}.
- _Leaf Routers_ receive requests from _Ingestion Routers_ and handle communication with the _leaves_ in a zone.

Metrics are assigned to a destination set of leafs within a zone using a component called the _Range Assigner_. The _Range Assigner_ handles load balancing metrics data across _leaves_ in order to ensure balanced usage of storage and other resources.

### Query Execution

To respond to queries, Monarch implements two main components: _Mixers_ and _Index Servers_. Copies of these components run at both the _Global_ and _Zone_ level.

_Mixers_ receive queries, and issue requests to the different components of the Monarch stack, and return the results. _Root Mixers_ run in the _global_ component of Monarch, while _Zone Mixers_ run in each zone. When _Root Mixers_ receive a query, they attempt to break it down into subqueries that can be issued independently to each _zone_. When a _Zone Mixer_ receives a request, it performs a similar function, fanning out to _leaves_.

In order to determine which zones or leaves to send queries to, the _Mixer_ communicates with an _Index Server_. Like _Mixers_, _Index Servers_ run at the _global_ and _zone_ level - _Root Index Servers_ store which zone data can be found in, while _Zone Index Servers_ store which leaves data can be found on.

Monarch implements several strategies to improve the reliability of query execution. One example is _Zone Pruning_, where the global Monarch query executor will stop sending requests to a zone if it is unhealthy (detected by network latency to the given zone). Another example strategy for improving reliability is _hedged reads_. For redundancy, Monarch stores multiple copies of a metric in a zone. As a result, the _Zone Mixer_ can issue multiple reads to different copies, returning when it has an acceptable result from one replica.

### Configuration

To configure Monarch, users interact with a global component that stores data in [Spanner](https://research.google/pubs/pub39966/){% sidenote 'spanner' "Spanner will have to be the subject of a future paper review!"%}. This configuration is then replicated to each _zone_.

Configuration controls the schemas discussed above, as well as _standing queries_ that run periodically in the background. _Standing queries_ are often used for implementing alerting based on executions at regular intervals. The paper notes that predominantly all queries in the system are of this type.

## How is the research evaluated?

The paper evalutes several parts of the system, including its scale and query performance.

Monarch's scale is measured by the number of time series it stores, the memory they consume, and the queries per second:

> [Monarch] has sustained fast growth since its inception and is still growing rapidly...As of July 2019, Monarch stored nearly 950 billion time series, consuming around 750TB memory with a highly-optimized data structure.

Notably, "Monarch’s internal deployment ingested around *2.2 terabytes of data per second* in July 2019."

{% maincolumn 'assets/monarch/scale.png' '' %}

When evaluating query performance, the paper notes that 95% of queries are _standing queries_, configured in advance by users. Standing queries are evaluated in parallel at the _zone_ level, enabling significant amounts of data to be filtered out of the query before being returned in a response.

## Conclusion

The Monarch paper is a unique example of a metrics database running at global scale. Along the way, the paper includes an interesting discussion of the tradeoffs it makes to increase availability at the cost of consistency.

Time-series databases, including those designed explicitly for metrics, are an active area of research, and I'm looking forward to seeing the development of open-source approaches targeted for similar scale, like [Thanos](https://thanos.io/tip/thanos/design.md/) and [M3](https://m3db.io/)!
