---
layout: post
title: "From Laptop to Lambda: Outsourcing Everyday Jobs to Thousands of Transient Functional Containers"
hn: "https://news.ycombinator.com/item?id=27950204"
categories:
---

_This week's paper review is the second in a series on "The Future of the Shell" (Part 1, a paper about possible ways to innovate in the shell is [here](/2021/07/14/unix-shell-programming-the-next-50-years.html)). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These weekly paper reviews can also [be delivered weekly to your inbox](https://newsletter.micahlerner.com/)._

[From Laptop to Lambda: Outsourcing Everyday Jobs to Thousands of Transient Functional Containers](https://www.usenix.org/system/files/atc19-fouladi.pdf)

This week's paper discusses _gg_, a system designed to  parallelize commands initiated from a developer desktop using cloud functions{% sidenote 'firecracker' "Like those running on AWS Lambda in [Firecracker VMs, as discussed in a previous paper review](/2021/06/17/firecracker-lightweight-virtualization-for-serverless-applications.html)." %} - an alternative summary is that _gg_ allows a developer to, for a limited time period, "rent a supercomputer in the cloud". 

While parallelizing computation using cloud functions is not a new idea on its own{% sidenote 'simdiff' "Related systems, like [Ray](/2021/06/27/ray-a-distributed-framework-for-emerging-ai-applications.html), are discussed later in this paper review."%}, _gg_ focuses specifically on leveraging affordable cloud compute functions to speed up applications not natively designed for the cloud, like [make](https://www.gnu.org/software/make/)-based build systems (common in open source projects), unit tests, and video processing pipelines.

## What are the paper's contributions?

The paper's contains two primary contributions: the design and implementation of _gg_ (a general system for parallelizing command line operations using a computation graph executed with cloud functions) and the application of _gg_ to several domains (including unit testing, software compilation, and object recognition). 

To accomplish the goals of _gg_, the authors needed to overcome three challenges: managing software dependencies for the applications running in the cloud, limiting round trips from the developer's workstation to the cloud (which can be incurred if the developer's workstation coordinates cloud executions), and making use of cloud functions themselves.

To understand the paper's solutions to these problems, it is helpful to have context on several areas of related work: 

- _Process migration and outsourcing_: _gg_ aims to outsource computation from the developer's workstation to remote nodes. Existing systems like [distcc](https://distcc.github.io/) and [icecc](https://github.com/icecc/icecream) use remote resources to speed up builds, but often require long-lived compute resources, potentially making them more expensive to use. In contrast, _gg_ uses cloud computing functions that can be paid for at the second or millisecond level.
- _Container orchestration systems_: _gg_ runs computation in cloud functions (effectively containers in the cloud). Existing container systems, like Kubernetes or Docker Swarm, focus on the actual scheduling and execution of tasks, but don't necessarily concern themselves with executing dynamic computation graphs - for example, if Task B's inputs are the output of Task A, how can we make the execution of Task A fault tolerant and/or memoized. 
- _Workflow systems_: _gg_ transforms an application into small steps that can be executed in parallel. Existing systems following a similar model (like Spark) need to be be programmed for specific tasks, and are not designed for "everyday" applications that a user would spawn from the command line. While Spark can call system binaries, the binary is generally installed on all nodes, where each node is long-lived. In contast, _gg_ strives to provide the minimal dependencies and data required by a specific step - the goal of limiting dependencies also translates into lower overhead for computation, as less data needs to be transferred before a step can execute. Lastly, systems like Spark are accessed through language bindings, whereas _gg_ aims to be language agnostic.
- _Burst-parallel cloud functions_: _gg_ aims to be a higher-level and more general system for running short-lived cloud functions than existing approaches - the paper cites [PyWren](http://pywren.io/) and [ExCamera](https://www.usenix.org/conference/nsdi17/technical-sessions/presentation/fouladi) as two systems that implement specific functions using cloud components (a MapReduce-like framework and video encoding, respectively). In contrast, _gg_ aims to provide, "common services for dependency management, straggler mitigation, and scheduling."
- _Build tools_: _gg_ aims to speed up multiple types of applications through parallelization in the cloud. One of those applications, compiling software, is addressed by systems like [Bazel](https://bazel.build/), [Pants](https://www.pantsbuild.org/), and [Buck](https://buck.build). These newer tools are helpful for speeding up builds by parallelizing and incrementalizing operations, but developers will likely not be able to use advanced features of the aforementioned systems unless they rework their existing build.

Now that we understand more about the goals of _gg_, let's jump into the system's design and implementation.

## Design and implementation of gg

_gg_ comprises three main components:

- The _gg Intermediate Representation (gg IR)_ used to represent the units of computation involved in an application - _gg IR_ looks like a graph, where dependencies between steps are the edges and the units of computation/data are the nodes.
- _Frontends_, which take an application and generate the intermediate representation of the program.
- _Backends_, which execute the _gg IR_, store results, and coalesce them when producing output.

{% maincolumn 'assets/gg/arch.png' '' %}

The _gg Intermediate Representation (gg IR)_ describes the steps involved in a given execution of an application{% sidenote 'dynamic' 'Notably, this graph is dynamic and lazily evaluated, which is helpful for supporting applications that involve "loops, recursion, or other non-DAG dataflows.'%}. Each step is described as a _thunk_, and includes the command that the step invokes, environment variables, the arguments to that command, and all inputs. Thunks can also be used to represent primitive values that don't need to be evaluated - for example, binary files like gcc need to be used in the execution of a thunk, but do not need to be executed. A _thunk_ is identified using a content-addressing scheme{% sidenote 'content' 'The paper describes a content-addressing scheme where, "the name of an object has four components: (1) whether the object is a primitive value (hash starting with V) or represents the result of forcing some other thunk (hash starting with T), (2) a SHA-256 hash, (3) the length in bytes, and (4) an optional tag that names an object or a thunk’s output."'%} that allows one _thunk_ to depend on another (by specifying the objects array as described in the figure below).

{% maincolumn 'assets/gg/thunks.png' '' %}

_Frontends_ produce the _gg IR_, either through a language-specific SDK (where a developer describes an application's execution in code){% sidenote 'ray' 'This seems like it would have a close connection to [Ray, another previous paper review](/2021/06/27/ray-a-distributed-framework-for-emerging-ai-applications.html).'%} or with a _model substitution primitive_. The model substitution primitive mode uses `gg infer` to generate all of the thunks (a.k.a. steps) that would be involved in the execution of the original command. This command executes based on advanced knowledge of how to model specific types of systems - as an example, imagine defining a way to process projects that use _make_. In this case, `gg infer` is capable of converting the aforementioned `make` command into a set of thunks that will compile independent C++ files in parallel, coalescing the results to produce the intended binary - see the figure below for a visual representation.

{% maincolumn 'assets/gg/ggir.png' '' %}

_Backends_ execute the _gg IR_ produced by the _Frontends_ by "forcing" the execution of the thunk that corresponds to the output of the application's execution. The computation graph is then traced backwards along the edges that lead to the final output. Backends can be implemented on different cloud providers, or even use the developer's local machine. While the internals of the backends may differ, each backend must have three high-level components:

- _Storage engine_: used to perform CRUD operations for content-addressable outputs (for example, storing the result of a thunk's execution).
- _Execution engine_: a function that actually performs the execution of a thunk, abstracting away actual execution. It must support, "a simple abstraction: a function that receives a thunk as the input and returns the hashes of its output objects (which can be either values or thunks)". Examples of execution engines are "a local multicore machine, a cluster of remote VMs, AWS Lambda, Google Cloud Functions, and IBM Cloud Functions (OpenWhisk)".
- _Coordinator_: The coordinator is a process that orchestrates the execution of a _gg IR_ by communicating with one or more execution engines and the storage engine{% sidenote 'coordinator' "It was unclear from the paper whether multiple storage engines can be associated with a single coordinator."%}. It provides higher level services like making scheduling decisions, memoizing thunk execution (not rerunning a thunk unnecessarily), rerunning thunks if they fail, and straggler mitigation{% sidenote 'straggler' "Straggler mitigation in this context means ensuring that slow-running _thunks_ do not impact overall execution time. One strategy to address this issue is uunning multiple copies of a thunk in parallel, then continuing after the first succeds - likely possible because content-addressable nature of thunks means that their execution is idempotent." %}.

## Applying and evaluating gg

The _gg_ system was applied to, and evaluated against, four{% sidenote "five" "The paper also includes an implementation of recursive fibonacci to demonstrate that _gg_ can handle dynamic execution graphs while also memoizing redundant executions."%} use cases: software compilation, unit testing, video encoding, and object recognition. 

For software compilation, FFmpeg, GIMP, Inkscape, and Chromium were compiled either locally, using a distributed build tool (icecc), or with _gg_. For medium-to-large programs, (Inkscape and Chromium), _gg_ performed better than the alternatives with an _AWS Lambda_ execution engine, likely because it is better able to handle high degrees of parallelism - a _gg_ based compilation is able to perform all steps remotely, whereas the two other systems perform bottlenecking-steps at the root node. The paper also includes an interesting graphic outlining the behavior of _gg_ worker's during compilation, which contains an interesting visual of straggler mitigation (see below). 

{% maincolumn 'assets/gg/stragglers.png' '' %}

For unit testing, the LibVPX test suite was built in parallel with _gg_ on AWS Lambda, and compared with a build box - the time differences between the two strategies was small, but that authors argue that the _gg_ based solution was able to provide results earlier because of its parallelism.

For video encoding, _gg_ performed worse than an optimized implementation (based on ExCamera), although the _gg_ based system introduces memoization and fault tolerance.

For object recognition, _gg_ was compared to [Scanner](https://scanner.run){% sidenote "scanner" '"Scanner is a distributed system for building efficient video processing applications that scale." - it would be interesting to see this implemented in Ray!'%}, and observed significant speedups{% sidenote "speedup" "The authors mention that the _gg_ implementation was specifically tuned to the task."%} that the authors attribute to _gg_'s scheduling algorithm and removing abstraction in Scanner's design.

## Conclusion

While _gg_ seems like an exciting system for scaling command line applications, it may not be the best fit for every project (as indicated by the experimental results) - in particular, _gg_ seems well positioned to speed up traditional make-based builds without requiring a large-scale migration. The paper authors also note limitations of the system, like _gg_'s incompatibility with GPU programs - [my previous paper review on Ray](/2021/06/27/ray-a-distributed-framework-for-emerging-ai-applications.html) seems relevant to adapting _gg_ in the future. 

A quote that I particularly enjoyed from the paper's conclusion was this: 

> As a computing substrate, we suspect cloud functions are in a similar position to Graphics Processing Units in the 2000s. At the time, GPUs were designed solely for 3D graphics, but the community gradually recognized that they had become programmable enough to execute some parallel algorithms unrelated to graphics. Over time, this “general-purpose GPU” (GPGPU) movement created systems-support technologies and became a major use of GPUs, especially for physical simulations and deep neural networks. Cloud functions may tell a similar story. Although intended for asynchronous microservices, we believe that with sufficient effort by this community the same infrastructure is capable of broad and exciting new applications. Just as GPGPU computing did a decade ago, nontraditional “serverless” computing may have far-reaching effects.

Thanks for reading, and feel free to reach out with feedback on [Twitter](https://twitter.com/micahlerner) - until next time!