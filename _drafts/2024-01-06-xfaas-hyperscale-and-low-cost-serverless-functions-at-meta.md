---
layout: post
title: "XFaaS: Hyperscale and Low Cost Serverless Functions at Meta"
categories:
---

["XFaaS: Hyperscale and Low Cost Serverless Functions at Meta"](TODO)

## Background

Function-as-a-Service systems (a.k.a. FaaS) allow engineers to run code without setting aside servers to a specific function. Instead, users of FaaS systems will run their code on generalized infrastructure (like AWS Lambda, Azure Functions, and GCP's Cloud Functions (TODO link)), and only pay for the time that they use.

## Key Takeaways

This paper describes Meta's internal system for serverless, called XFaaS, which runs "trillions of function calls per day on more than 100,000 servers".

TODO figure 3

Besides characterization of this unique at-scale serverless system, the paper dives deeper on several challenges that they authors addressed before reaching the current state of the infrastructure:

- Handling load spikes of function executions, as systems in Meta can schedule large numbers of function executions.
- Ensuring fast function startup and execution, which can impact the developer experience and decrease utilization.
- Global load balancing across Meta's distributed private cloud, so as not to overload any single datacenter
- Ensuring high-utilization of resources to limit cost increases from running the system.
- Preventing overload of downstream services, as functions often access or update data via RPC requests when performing computation.

TODO figure 4
TODO figure 5

## How does the system work?

### Architecture

The multi-region infrastructure of XFaaS contains TODO main components: _Submitter_, _load balancers_, _DurableQ_, _Scheduler_, and _Worker Pool_.

TODO Figure 6

Clients of the system schedule function execution by communicating with the _Submitter_. Functions can take one of three types:

> (1) queue-triggered functions, which are submitted via a queue service; (2) event-triggered functions, which are activated by data-change events in our data warehouse and data-stream systems; and (3) timer-triggered functions, which automatically fire based on a pre-set timing.

TODO Table 1

The _submitter_ is an interesting design choice because it introduces _isolation_. Before the pattern was introduced, clients interfaced with downstream components of the system directly, allowing badly behaved services to overload XFaaS - now, clients receive default quota, and the system throttles those that exceed this quota (although there is a process for negotiating higher quota as needed).

The next stage in the request flow is forwarding the initial function execution request to a load balancer (_Queue Load Balancers (QueueLB)_) sitting in front of the durable storage (_DurableQ_) that contains metadata about the function. The QueueLB is just one example of load balancers that ensure effective utilization of system resources while preventing overload.

Once the information about a function is stored in a _DurableQ_, a _scheduler_ will eventually attempt to run it - given that there are many clients of XFaaS, the scheduler, "determine(s) the order of function calls based on their criticality, execution deadline, and capacity quota". This ordering is represented with in-memory datastructures called the _FuncBuffer_ and the _RunQ_ - "the inputs to the scheduler are multiple FuncBuffers (function buffers), one for each function, and the output is a single ordered RunQ (run queue) of function calls that will be dispatched for execution."

To assist with load-balancing computation, a scheduler can also choose to run functions from a different region if there aren't enough functions to run it the local-region - this decision is based on a "traffic matrix" that XFaaS computes to represent how much load a region should externally source (e.g. Region A should source functions from Regions B, C, and D because they're under relatively higher load).

Once the scheduler determines that there is sufficient capacity to run more functions, it assigns the execution to a _WorkerPool_ using a load-balancer approach similar to the _QueueLB_ mentioned earlier.

Given the large numbers of different functions in the system, one challenge with reaching  high worker utilization is reducing the memory and CPU resources that workers spend on loading function data and code. XFaaS addresses this constraint by implementing _Locality Groups_ that limit a function's execution to a subset of the larger pool.

### Performance Optimizations

The paper mentions two other optimizations to increase worker utilization: _time-shifted computing_ and _cooperative JIT compilation_.

_Time-shifted computing_ introduces flexibility in the timing of a function execution - for example, rather than specififying "this function must execute immediately", XFaaS can delay the computation to a time when other functions aren't executing, smoothing resource utilization. Importantly, users of the system are incentivized to take advantage of this flexibility as functions have two different quotas, _reserved_ and _opportunistic_ (mapping to more or less rigid timing), where _opportunistic_ quota is internally treated as "cheaper".

Additionally, the code in Meta's infrastructure takes advantage of [profiling-guided optimization](https://blog.acolyer.org/2018/08/08/hhvm-jit-a-profile-guided-region-based-compiler-for-php-and-hack/), a technique that can dramatically improve performance. XFaaS ensures that these performance optimizations computed on one worker are not recomputed on others by shipping the optimized code across the fleet.

### Preventing Overload

It is critical that accessing downstream services, don't cause or worsen their overload - an idea very similar to what was discussed in a previous paper review on [Metastable Failures in the Wild](https://www.micahlerner.com/2022/07/11/metastable-failures-in-the-wild.html). XFaaS implements this by borrowing the idea of [_backpressure_](https://medium.com/@jayphelps/backpressure-explained-the-flow-of-data-through-software-2350b3e77ce7) from TCP (specifically [Additive increase/multiplicative decrease](https://en.wikipedia.org/wiki/Additive_increase/multiplicative_decrease)) and other distributed systems.

## How is the research evaluated?

The paper evaluates the system's ability to achieve high utilization, efficiently execute functions while taking advantage of performance improvements, and prevent overload of downstream services.

To evaluate XFaaS's ability to maintain high utilization and smooth load, the authors compare the rate of incoming requests to the load of the system - "the peak-to-trough ratio of CPU utilization is only 1.4x, which is a significant improvement over the peak-to-trough ratio of 4.3x depicted...for the _Received_ curve."

TODO figure 2
TODO figure 7

One reason for consistently high load is the incentive to allow flexibility in the execution of their functions, highlighted by usage of the two quota-types described by the paper.

TODO figure 11

To determine the effectiveness of assigning a subset of functions to a worker, the authors share time series data on the number of functions executed by workers and memory utiliation across the fleet, finding that both stay relatively constant.

TODO figure 9
TODO figure 10

Furthermore, XFaaS' performance optimizations allow it to maintain a relatively high throughput, visible from contrasting requests per-second with and without profile-guided optimizations in place.

TODO figure 12

Lastly, the paper presents how XFaaS execution behaves in response to issues with downstream systems (specifically, not exacerabating outages). For example, when there were outage in Meta's graph database (TAO, the subject of a previous paper review), or infrastructure related to it, XFaaS reduced the execution of functions accessing these services.

TODO figure 13
TODO figure 14

## Conclusion

The XFaaS paper is interesting because it is a characterization of a serverless system running at immmense scale. While there have been studies of these systems before, many of them lack details due to privacy or business concerns (e.g. the one of Azure Functions TODO). At the same time, XFaaS is able to make some design choices because it is operating within a different problem space than serverless infrastructure for the public cloud. For example, public clouds must guarantee isolation between customers and prioritize security considerations. While XFaaS doesn't wholly neglect these concerns (e.g. some jobs must run on separate machines and there are some levels of isolation between jobs with these considerations), it otherwise relaxes this constraint. Lastly, XFaaS explicitly doesn't handle functions and the path of a user-interaction, even if there are latency-sensitive functions that it executes. This is in contrast with services like Lambda which use Serverless functions to respond to HTTP requests. Lastly, another critique of XFaaS is that some of the functions it describes seem potentially better as a batch job - it would be interesting to see what these services did before using it and compare the pros/cons (e.g. does XFaaS actually add overhead)?
