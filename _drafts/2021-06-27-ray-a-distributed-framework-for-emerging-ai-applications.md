---
layout: post
title: "Ray: A Distributed Framework for Emerging AI Applications"
categories:
---

[Ray: A Distributed Framework for Emerging AI Applications](https://www.usenix.org/system/files/osdi18-moritz.pdf) Moritz, Nishihara, Wang et. al.

_This week I decided to revisit a paper from the 2018 edition of OSDI (Operating Systems Design and Impelementation). In the coming few weeks, I will likely be reading the [new crop of papers from HotOS 2021](https://sigops.org/s/conferences/hotos/2021/). If there are any that look particuarly exciting to you, feel free to ping me on [Twitter](https://twitter.com/micahlerner)!_

Ray is a thriving open source project focused on ["providing a universal API for distributed computing"](https://docs.google.com/document/d/1lAy0Owi-vPz2jEqBSaHNQcy2IBSDEHyXNOQZlGuj93c/preview#heading=h.ojukhb92k93n0) - in other words trying to build primitives that allow applications to easily run and scale (even across multi-cloud environments). Part of what excites me about Ray are the [demos](https://www.youtube.com/watch?v=8GTd8Y_JGTQ) from Anyscale, which show how easy it is to parallelize computation{% sidenote 'Anyscale' 'Anyscale is a company founded by the original authors of the paper - Apache Spark is to Databricks, what Anyscale is to Ray.' %}. The idea that (somewhat) unlimited cloud resources could be used to drastically speed up developer workflows is an exciting area of research - for a specific use case see [From Laptop to Lambda:  Outsourcing Everyday Jobs to Thousands  of Transient Functional Containers](https://stanford.edu/~sadjad/gg-paper.pdf).

While the current vision of the project has changed somewhat from the published paper (which came out of Berkeley's [RISELab](https://rise.cs.berkeley.edu/){% sidenote 'rise' 'The RISELab is the ["successor to the AMPLab"](https://engineering.berkeley.edu/news/2017/01/berkeley-launches-riselab-enabling-computers-to-make-intelligent-real-time-decisions/), where Apache Spark, Apache Mesos, and other "big data" technologies were originally developed)' %}), it is still interesting to reflect on the original architecture and motivation.

Ray was originally developed with the goal of supporting modern RL applications that must:

- Execute large numbers of millisecond-level computations (for example, in response to user requests)
- Execute workloads on heterogenous resources (running some system workloads on CPUs and others on GPUs)
- Quickly adapt to new inputs that impact a reinforcement-learning simulation

The authors argue that existing architectures for RL weren't able to achieve these goals because of their a-la-carte design - even though technologies existed to solve individual problems, none were able to accomplish all of them, nor do so in a low-latency environment.


## What are the paper's contributions?

The Ray paper has three main contributions: a generic system designed to train, simulate, and server RL models, the _design and architecture_ of that system, and a _programming model_ used to write workloads that run on the system. We will dive into the programming and computation model first, as they are key to understanding the rest of the system.

## Programming and computation model

Applications that run on Ray are made up of runnable subcomponents with two types: _tasks_ or _actors_. 

_Tasks_ are a stateless function execution that rely on their inputs in order to produce a future result (a common abstraction of asynchronous frameworks{% sidenote 'futures' "For more on futures, I would recommend [Heather Miller's book on  Programming Models for Distributed Computing](http://dist-prog-book.com/chapter/2/futures.html)."%}). A programmer can make a future depending on another future's result, like one would be able to in most asynch programming frameworks. 

_Actors_ are functions that represent a stateful computation (like a counter), and can depend on or be depended on by other computations. Because they require maintenance of state, they are also more difficult to implement.

Because _Tasks_ and _Actors_ in an application can depend on one another, Ray represents their execution as a graph. The nodes in the graph are computation or state that computation produces, while the edges in the graph describe relationships between computations and/or data. Representing computation as a graph allows the state of an application be to re-executed as needed - for example, if part of the state is stored on a node that fails, that state can be recovered {% sidenote 'lineage' "The authors dig further into representing "lineage" in a future paper [here](https://dl.acm.org/doi/pdf/10.1145/3341301.3359653)."%}.

{% maincolumn 'assets/ray/api.png' '' %}

To instatiate _tasks_ and _actors_, Ray provides a developer API in Python (and now in other languages). To initialize a remote function, a developer can add the `@ray.remote` decorator. The example below (from the open source project docs [here](https://github.com/ray-project/ray#quick-start)) shows how one would create a remote function to square a range of numbers, then wait on the results.

```
import ray
ray.init()

@ray.remote
def f(x):
    return x * x

futures = [f.remote(i) for i in range(4)]
print(ray.get(futures))
```


## Architecture

Ray aims to run _Tasks_ and _Actors_ created by developers in a fault-tolerant manner. To do so, it implements a distributed system containing two layers: the _Application Layer_ and the _System Layer_. 

{% maincolumn 'assets/ray/arch.png' '' %}


### The Application Layer
The _Application Layer_ has three components: a singleton _driver_ (which orchestrates a specific user program on the cluster), _workers_ (processes that run tasks), and _actors_ (which as the name suggests, run _Actors_ mentioned in the previous section).

### The System Layer
The _System Layer_ is significantly more complex, and comprises three components: a _Global Control Store_ (which maintains state of the system), a _scheduler_ (which coordinates running computation), and a _distributed object store_ (which store the input and output of computation).

The _Global Control Store_ (a.k.a. GCS) is a key-value store that maintains the state of the system. One of its key functions is maintaining the lineage of execution so that the system can recover in the event of failure. The authors argue that separating the system metadata from the scheduler allows every other component of the system to be stateless (making it easier to reason about how to recover if the different subcomponents fail). The original paper does not dive into the subcomponents of the _GCS_, but the [Ray v1.x Architecture paper](https://docs.google.com/document/d/1lAy0Owi-vPz2jEqBSaHNQcy2IBSDEHyXNOQZlGuj93c/preview#) provides more context.

{% maincolumn 'assets/ray/scheduler.png' '' %}

The _Scheduler_ operates "bottoms up" in order to assign the execution of a function to a specific node in the cluster. In contrast to existing schedulers, the Ray scheduler aims to schedule millions of tasks per second (where the tasks are possibly short lived), while also taking into account data locality{% sidenote 'assumptions' 'The paper also mentions other assumptions that existing schedulers make - other schedulers "assume tasks belong to independent jobs, or assume the computation graph is known."' %}. Data locality matters for scheduling because the output of computation will end up on a specific node - transferring that data to another node incurs overhead. The scheduler is called "bottoms up" because tasks are first submitted to a local scheduler, only bubbling up to a global scheduler if they cannot be scheduled on the local machine.

Lastly, the _distributed object store_ stores immutable inputs and outputs of every task in memory, transferring the inputs for a task to a different machine if needed (for example, if the local scheduler can't find resources).

## Evaluation and microbenchmarks

The original paper evaluates whether Ray achieves the desired goal of being able to schedule millions of tasks with variable running times, and whether doing so on heterogenous architecture provides any benefits. A few of the benchmarks stick out to me, primarily those that show how Ray is able to take advantage of heterogenous computing resources. 

{% maincolumn 'assets/ray/ppo.png' '' %}

Ray is primarily impressive in this regard:

> Ray implementation out-performs the optimized MPI implementation in all experiments, while using a fraction of the GPUs. The reasonis that Ray is heterogeneity-aware and allows the user to utilize asymmetric architectures by expressing resource requirements at the granularity of a task or actor. The Ray implementation can then leverage TensorFlow’s single-process multi-GPU support and can pin objects in GPU memory when possible. This optimization cannot be easily ported to MPI due to the need to asynchronously gather rollouts to a single GPU process

For the Proximal Policy Optimization (PPO) algorithm (more information [on PPO](https://openai.com/blog/openai-baselines-ppo/)), the system is able to scale much better than an OpenMPI alternative: "Ray’s fault tolerance and resource-aware scheduling together cut costs by 18×."

## Conclusion

While originally designed as a system for RL applications, Ray is paving an exciting path forward in computing by providing abstractions on top of cloud resources (in particular, I'm excited to see how the projects innovates in multi-cloud deployments). They have an detailed design document for the new version of the system [here](https://docs.google.com/document/d/1lAy0Owi-vPz2jEqBSaHNQcy2IBSDEHyXNOQZlGuj93c/preview#).

If you find this paper interesting, [Ray Summit](https://raysummit.anyscale.com/speakers) was last week and covers various Ray system internals (in addition to discussions of the technology being adopted in industry). 