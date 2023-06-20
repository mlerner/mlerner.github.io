---
layout: post
title: "Towards an Adaptable Systems Architecture for Memory Tiering at Warehouse-Scale"
categories:
---

_This is one in a series of papers I'm reading from ASPLOS. These paper reviews can be [delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions!_

Applications running in datacenter environments require memory to operate. The raw resources are often abstracted away from the application, which instead integrates with a scheduler (TODO link to borg and other schedulers). This paper seeks to provide memory to applications running in datacenters, but actually optimize the type of resource that the application is using.

Schedulers are capable of doing this because many applications aren't fully using objects in memory that they've been assigned. The scheduler is able to analyze the application's actual usage of memory and migrate objects to cheaper resources, fully abstracted away from the application. The research is able to achieve successfully trade off minor performance degradation when the applications actually do end up using data that is on a lower quality / slower memory resources for significant cost savings.


## What are the paper's contributions?

The paper makes three main categories of contributions:

- Design and implementation of a memory tiering system.
- A testing methodology for evaluating changes to the system at scale.
- Lessons and evaluation from running the implementation in production.

## How does the system work?

## System metrics

To decide how an application should be treated with respect to memory tiering, the paper discusses the fact that some applications on the critical path of user requests are considered "high importance latency sensitive", while other applications (for example, batch pipelines) are more tolerant to performance degradation.

The paper discusses the key tradeoff the system needs to make between potential cost savings and performance degradation. The authors also discuss how a two tier system needs to be able to identify applications that are able to use lower performance hardware - otherwise, the lower performance hardware will sit around being unutilized, so the potential cost savings will not occur _and_ there are more resources that you've paid for. Additionally, if there is lower performance hardware, applications that must run on the high performance will be impacted.

Using these two considerations, the paper defines two metrics that the system can use to judge how good of a job the memory tiering system is doing: _Secondary Tier Residency Ratio (STRR)_ and _Secondary Tier Access Ratio (STAR)_.

> - _Secondary Tier Residency Ratio (STRR)_ is the fraction of allocated memory residing in tier2. It provides a normalized perspective on tier usage. STRR serves as a proxy for measuring impact to utilization.
> - _Secondary Tier Access Ratio (STAR)_ is the fraction of all memory accesses of an application directed towards pages resident in tier2. A lower STAR means a lower performance impact. STAR serves as a proxy for application performance degradation.

The goal of the system is to minimize STAR and maximize STRR - in other words, maximize usage of lower performance memory (high STRR) without impacting application performance (low STAR).

TODO figure 1

### System Architecture

The memory tiering system is divided into four levels of abstraction: _hardware_, _kernel_, _userspace_, and the _cluster_.

At the bottom of the stack is the underlying _hardware_, made up of several types of memory devices with different performance and cost profiles.

Immediately above the hardware is the _kernel_, which groups the hardware into different tiers, and operates on hardware abstractions like memory pages (TODO cite memory pages). Inside the kernel, there are also daemons that scan memory to understand an application's usage . In user space, a daemon (ufard) describes the demotion and promotion policies for memory between tier1 and tier2, then conveys that information to the kernel. At the top layer, the cluster schedulers makes decision about where to run applications based on their memory needs.

### Cold page demotion and hot page promotion

A key component of the memory system is demoting cold pages to low-cost memory, and promoting hot pages to higher performance resources. A page is classified as "cold with threshold t if it has not been accessed in the prior t seconds", and the policy about when to demote pages to cold memory is dependent on the needs of the application. The policy can also be adaptive, for example "the kernel provides the userspace daemon a cold age histogram - the frequency distribution of inter-access interval duration. It answers questions such as how many pages were not accessed for at least 2 minutes. The policy engine uses this to identify application access patterns and adjust parameter values."

To promote pages from tier2 to tier1, the tiered memory system relies on two approaches: _proactive promotion_ and _periodic scanning_.

Proactive promotion aims to move pages from tier2 to tier1 ahead of time, rather than waiting until a fault occurs (which would introduce latency). This proactive process is informed by signals from hardware (in particular the hardware PMU) - for example, sampling cache miss events provides insights into which pages are not in the last level cache (TODO describe the last level cache and why it matters).

_Periodic scanning_ complements the sampling-based approach by scanning pages over repeating perdios and promoting them based on how many consecutive "scan periods" the page has been accessed in. This approach is more accurate, but higher overhead. The system also aims to limit _thrashing_ - if a page is potentially going to be demoted, but was recently promoted, the demotion doesn't perform similarly (to prevent thrashing).

These monitoring processes use a combination of [perf_event_open](https://www.man7.org/linux/man-pages/man2/perf_event_open.2.html){% sidenote 'perfevent' "TODO research perf_event_open."%} and BPF in the kernel{% sidenote 'bpf' "TODO link to BPF context"%} which "optimize[s] the collection of tier2 hot page ages and their page addresses from the in-kernel page."

## How is the research evaluated?

### System Evaluation

The TMTS system is deployed in production and is constantly evolving to perform more effectively. To evaluate the system, the paper considers three areas: _memory utilization / task capacity_, _residency ratios_, _access ratios / bandwidth_, and _overall performance impact_

_Memory utilization / task capacity_ represents the impact that the system has on individual applications - if an application is performing poorly (for example, serving requests with high user facing latency), the scheduler will schedule more tasks (higher task capcity) or put fewer tasks on the impacted machines (lower utiliation). The paper presents data that shows memory utilization and task capacity isn't impacted by the memory tiering system.

TODO figure 4

_Residency ratios_ provide a sense of how successful the system is at storing cold pages in tier2 memory. First, the paper shows that the STRR (representing TODO) is close to the percentage of deployed tier2 hardware. Additionally, the paper includes data on the ratio of cold memory stored in tier2, which is between 50 and 75% across all clusters - notably, the paper compares this to swap based solutions which TODO.

TODO figure 5

_Access ratios / bandwidth_ are used to understand if the pages in tier2 are accessed frequently (which would impact performance). Additionally, there is data on how much bandwidth is used by the promotion/demotion process - "bout 80% of tier2 bandwidth is due to applications accessing pages resident in that tier, promotion being about 1/3 of the remaining and demotion 2/3".

TODO figure 7

_Overall performance impact_ is important to understand, as it is core to the tradeoffs that the system is making. The metric that the paper uses is instructions per cycle (IPC). The authors were targeting a performance impact of 5%, but some applications are impacted more severely.

TODO Figure 6

The paper presents data that digs in deeper into the performance impact of tier2 memory. One example performance impact is for so-called huge pages (TODO reference huge pages research). Hugepagers can take up to TODO amount of memory, but accesses to a small part of the hugepage can cause it be promoted. Demoting hugepages is also difficult because while the system would break up the hugepages into smaller components when demoting, a "mostly cold" hugepage wouldn't be demoted. The solution was "migrating hugepages intact, without breaking them apart into 4KB pages on demotion." - this had minimal computational impact, but saved a lot of memory in tier1.

TODO figure 8

### Policy Evaluation

Beyond the performance of the system itself, the paper also considers the impact that different policies can have on the northstar metrics it is optimizing for.

Demotion policies are capable of changing the amount of cold memory in tier2 by running more frequently or looking at additional datasources, with the tradeoff that these changes could increase overhead. The paper describes using two different policies, one with a static "demotion age", and another policy with different demotion ages for differen types of applications. Using a different demotion policy for HILS vs non-HILS is able to increase the STAR for HILS.

The paper also discusses promotion policies, and argues that applications are actually more sensitive to situations when a page is not yet promoted. There are three policies that the paper considers: 60s promotion (2 30 second scans), 30s (1 30s scan), combination of 60s promotion and PMU-based sampling. Effectively all policies have the same outcome with respect to memory ending up in tier1, but the combined approach (described earlier in the paper) is able to successfully promote pages because of TODO.

## Conclusion

The paper is interesting because it illustrates the tradeoffs between system performance and cost for hardware resources at scale. As memory is projected to be one of the performance bottlenecks for future applications (and also due to supplychain issues).