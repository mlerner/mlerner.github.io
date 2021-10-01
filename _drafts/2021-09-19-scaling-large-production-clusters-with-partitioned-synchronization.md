---
layout: post
title: "Scaling Large Production Clusters with Partitioned Synchronization"
categories:
---

_This is the second to last paper we will be reading from [Usenix ATC](https://www.usenix.org/conference/atc21) and [OSDI](https://www.usenix.org/conference/osdi21). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://tinyletter.com/micahlerner/), or you can subscribe to the new [Atom feed](https://www.micahlerner.com/feed.xml)._

[Scaling Large Production Clusters with Partitioned Synchronization](https://www.usenix.org/system/files/atc21-feng-yihui.pdf)

This week's paper review won a best paper award at Usenix ATC, and discusses Alibaba's approach to scaling their production environment. In particular, the paper focuses on the evolution of the scheduling architecture used in Alibaba datacenters in response to growth in workloads and resources{% sidenote 'scale' "An increase in resources or workloads impacted the load on the existing scheduler architecture. The former translates into more options for the scheduler to choose from when scheduling, and the latter means more computation that needs to be performed by the scheduler."%}. Beyond discussing Alibaba's specific challenges and solutions, the paper also touches on the landscape of existing scheduler architectures (like Mesos, YARN, and Omega). 


## Scheduler architectures

The paper first aims to decide whether any existing scheduling architectures meet the neeeds of Alibaba's production environment - any solution to the scaling problem's encountered by Alibaba's system needed to not only scale, but also simultaneously provide backward compatibility for existing users of the cluster (who have invested significant engineering effort to ensure their workloads are compatible with existing infrastructure). 

 To evaluate future scheduler implementations, the authors considered several requirements:

- _Low scheduling delay_: the selected scheduler should be capable of making decisions quickly.
- _High scheduling quality_: if a task specifies preferences for resources, like running on "machines where its data are stored" or "machines with larger memory or faster CPUs", those preferences should be fulfilled as much as possible.
- _Fairness_: tasks should be allocated resources according to their needs (without being allowed to hog them){% sidenote 'fairness' "There are a number of interesting papers on fairness, like [Dominant Resource Fairness: Fair Allocation of Multiple Resource Types](https://cs.stanford.edu/~matei/papers/2011/nsdi_drf.pdf) (authored by founders of Spark and Mesos)."%}
- _Resource utilization_: the scheduler should aim to use as much of the cluster's resources as possible.

These requirements are then applied to four existing scheduler architectures{% sidenote "omega" "The [Omega paper](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/41684.pdf) is also an excellent resource on this topic, and the figure below is sourced from there" %}:

- _Monolithic_: an architecture with a single instance that lacks parallelism, common in HPC settings or lower-scale cloud environments.
- _Statically partitioned_: generally used for fixed-size clusters that run dedicated jobs or workloads (like Hadoop).
- _Two-level_: a scheduling strategy where a central cordinator assigns resources to sub-schedulers. This is implemented by [Mesos](https://people.eecs.berkeley.edu/~alig/papers/mesos.pdf), which uses "frameworks" to schedule tasks on resources offered by the central scheduler. A Mesos-like implementation is labeled "pessimistic concurrency control" because it aims to ensure that there will few (or no) conflicts between schedulers.
- _Shared-state_: one or more schedulers read shared cluster metadata about resources, then use that metadata to make scheduling decisions.  To schedule tasks, the independent schedulers try to modify the shared state. Because multiple schedulers are reading from and attempting to write to the same state, modifications may conflict. In the event of a conflict, one of the schedulers fails and re-evaluates its scheduling decision. [Omega](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/41684.pdf) is a shared-state scheduler cited by the authors. An Omega-like implementation utilizes "optimistic concurrency control" because the design assumes that there will be few conflicts between schedulers.

{% maincolumn 'assets/parsync/schedulerarch.png' 'Scheduler architecture diagram sourced from the [Omega paper](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/41684.pdf)' %}

The authors decide, after applying their requirements to existing scheduler architectures, to extend the design of _Omega_. The paper notes that a potential issue with an _Omega_-based architecture at scale is _contention_. _Contention_ occurs when multiple schedulers attempt to schedule tasks with the same resources - in this situation, one of the scheduling decisions succeeds, and all others could be rejected, meaning that the schedulers who issued the now-failed requests need to re-calculate scheduling decisions. The authors spend the majority of the paper evaluating how contention can be reduced, as it could pose a limit to the scalability of the future scheduler. In the process, the paper performs multiple simulations to evaluate the impact of adjusting critical scheduling-related variables.

## What are the paper's contributions?

The paper makes three contributions. After outlining existing scheduler architectures, it evaluates (using simulation techniques) whether any prior approaches are applicable to Alibaba's production environment. Using these results, the paper suggests an extension to the shared-state scheduling architecture. Lastly, the paper characterizes the performance of this solution, and provides a framework for simulating its performance under a variety of loads.

## Modeling scheduling conflicts

As mentioned above, more tasks competing for the same set of resources means contention - jobs will try to schedule tasks to the same slots ("slots" in this context correspond to resources). Given the optimistic concurrency control approach taken in an _Omega_-influenced shared-state scheduler, the paper argues that there will be latency introduced by scheduling conflicts. 

To evaluate potential factors that impact in a cluster under high load, the paper considers the effect of additional schedulers. Adding extra schedulers (while keeping load constant) spreads the load over more instances. Lower per-scheduler loads corresponds to lower delay in the event of contention{% sidenote 'contention' "If a scheduling decision fails, the failed request doesn't compete with a long queue of other requests." %}, although there are diminishing returns to flooding the cluster with schedulers{% sidenote 'cost' 'Not to mention the cost of adding more schedulers - each scheduler likely has multiple backup schedulers running, ready to take over if the primary fails.' %}.

For each number of schedulers, the simulation varies:

- _Task Submission Rate_: the number of decisions the cluster needs to make per unit time.
- _Synchronization Gap_: how long a scheduler has in between refreshing its state of the cluster.
- _Variance of slot scores_: the number of "high-quality" slots available in the system. This is a proxy for the fact that certain resource types in the cluster are generally more preferred in the cluster, leading to hotspots.
- _The number of partitions of the master state_: how many subdivisions of the master state there are (each part of the cluster's resources would be assigned to a partition).

To evaluate the performance of different configurations, the experiment records the number of extra slots required to maintain a given scheduling delay. The count of additional slots is a proxy for actual performance. For example, if the task submission rate increases, one would expect that the number of extra slots required to maintain low scheduling delay would also increase. On the other hand, changing experimental variables (like the number of partitions of the master state) may not require more slots or schedulers.

{% maincolumn 'assets/parsync/sim.png' '' %}

The experimental results indicate that flexibility in the system lies in the quality of the scheduling (_Variance of slot scores_) and in the staleness of the local states (_Synchronization Gap_). In other words, a scheduler can perform better for two reasons. First, it is critical that a scheduler can choose to make non-optimal scheduling decisions (meaning that tasks can run even if they aren't doing so on their preferred resources). Second, a scheduler that updates its state more frequently would have a more up-to-date view of the cluster (meaning that it would make fewer scheduling decisions that collide with recent operations by the other schedulers in the cluster). Because of these results, the authors choose to focus their implementation on improving these two facets of the scheduler.

## Partitioned Synchronization

To allow scheduler to efficiently make (occasionally) non-optimal decisions, the authors suggest an approach called _partitioned synchronization_ (a.k.a _ParSync_) with the goal, "to reduce the staleness of the local states and to find a good balance between resource quality (i.e., slot score) and scheduling efficiency". _ParSync_ works by syncing partitions of a cluster's state to one of the many{% sidenote 'parsync' "The previous section notes that there are significant performance benefits to adding schedulers in a shared-state architecture, up to a point."%} schedulers in a cluster. Then, the scheduling algorithm weights the recency (or _staleness_) of a partition's state in scheduling decisions. 

The authors argue that short-lived low latency tasks, as well as long-running batch jobs benefit from _ParSync_. For example, if a task is short lived, it should be quickly scheduled - a non-ideal scheduler would take more time making decisions than the task takes to actually run. In this situation, _ParSync_-based scheduling can assign the task to a recently updated partition, with high likelihood that the scheduling decision will succeed - other schedulers will not update the partition's state at the same time, instead preferring their own recently updated partitions. On the other side of the spectrum, a long running job might prefer certain resources, trading off more time spent making a scheduling decision for running with preferred resources.

_ParSync_ is coupled with three scheduling strategies: 

- _Quality-first_: optimize for use of preferred resources.
- _Latency-first_: optimize for faster scheduling decisions (even if they are non-optimal).
- _Adaptive_: use the Quality-first or Latency-first strategy depending on whether scheduling delay is high or not. If there is low scheduling delay, the scheduler will prefer quality-first. If there is high scheduling delay, the scheduler prefers latency-first.

The next section discusses the performance of the three different strategies.

## Evaluation

The paper results indicate that both quality-first and latency-first scheduling strategies (predictably) don't adapt to conditions they are not optimized for. Quality-first scheduling experiences latency at high load (when the scheduler should make decisions quickly), while latency-first scheduling generally makes worse scheduling decisions under low load (when the scheduler could take more time and choose ideal resources). In contrast, the adaptive strategy is able to switch between the aforementioned strategies, while achieving high resource utilization.

{% maincolumn 'assets/parsync/eval.png' '' %}

## Conclusion

This paper discusses a number of interesting scheduler architectures, as well as touching on the body of work covering scheduler internals{% sidenote "firmament" "See [Dominant Resource Fairness: Fair Allocation of Multiple Resource Types](https://cs.stanford.edu/~matei/papers/2011/nsdi_drf.pdf) and [Firmament: Fast, Centralized Cluster Scheduling at Scale](https://www.usenix.org/system/files/conference/osdi16/osdi16-gog.pdf)" %} (which I would love to read in the future). While the content of this paper leans heavily on simulation, there is a discussion of performance evaluation using internal Alibaba tools - I'm hopeful that we will be able to learn more about the real world performance of the team's scheduler in future research (as we often see we industry papers). 

As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with any feedback or paper suggestions. Until next time!