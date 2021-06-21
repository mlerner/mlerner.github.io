---
layout: post
title: "Firecracker: Lightweight Virtualization for Serverless Applications"
categories:
---

[Firecracker: Lightweight Virtualization for Serverless Applications](https://www.usenix.org/conference/nsdi20/presentation/agache) Agache et al., NSDI '20

_This week's paper review is a bit different than the past few weeks (which have been about distributed key-value stores). Inspired by all of the neat projects being built with the technology discussed in this paper, I decided to learn more. Enjoy!_

Firecracker is a high-performance virtualization solution built to run Amazon's serverless{% sidenote 'serverless' 'Serverless meaning that the resources for running a workload are provided on-demand, rather than being paid for over a prolonged time-period. Martin Fowler has some great docs on the topic [here](https://martinfowler.com/articles/serverless.html).'%} applications securely and with minimal resources. It now does so at immense scale (at the time the paper was published, it supported "millions of production workloads, and trillions of requests per month").

Since the paper was published, there has a been a buzz of interesting projects built with Firecracker. [Fly.io](https://fly.io) (a speed-focused platform for running Docker applications{% sidenote 'fly' "Apologies if a Fly.io engineer reads this and has a different short summary of the company. I did my best." %}) wrote about using the technology on their [blog](https://fly.io/blog/sandboxing-and-workload-isolation/), [Julia Evans](https://jvns.ca) wrote about booting them up for a [CTF she was building](https://jvns.ca/blog/2021/01/23/firecracker--start-a-vm-in-less-than-a-second/), and [Weave Ingite](https://github.com/weaveworks/ignite) lets you launch virtual machines from Docker{% sidenote 'vms' "Virtual machines and containers are sometimes conflated to be one and the same, but the internals are different. The difference is discussed later in this paper review! :)"%} containers (and other [OCI](https://opencontainers.org/){% sidenote 'oci' 'OCI stands for "Open Container Initiative" and works to define standards for containers and the software that runs them. A nice thing about OCI containers is that you can run them (with a container runtime) that complies with the standards, but has different internals. For example, one could choose [Podman](https://podman.io/) instead of Docker.'%} images).

Now that you are excited about Firecracker, let's jump into the paper!

## What are the paper's contributions?

There are two main contributions from the paper: the Firecracker system itself (already discussed above), and the usage of Firecracker to power AWS Lambda (Amazon's platform for running serverless workloads).

Before we go further, it is important to understand the motivation behind building Firecracker in the first place.

Originally, Lambda functions ran on a separate virtual machine (VM) for every customer (although functions from the same customer would run in the same VM). Allocating a separate VM for every customer was great for isolating customers from each other - you wouldn't want Company A to access Company B's code or functionality, nor for Company A's greedy resource consumption to starve Company B's Lambdas of resources. 

Unfortunately, existing VM solutions required significant resources, and resulted in non-optimal utilization. For example, a customer might have a VM allocated to them, but the VM is not frequently used. Even though the VM isn't used to its full capacity, there is still memory and CPU being consumed to run the VM. The Lambda system in this form was less-efficient, meaning it required more resources to scale (likely making the system more expensive for customers).

With the goal of increasing utilization (and lowering cost), the team established constraints of a possible future solution: 

- _Overhead and density_: Run "thousands of functions on a single machine, with minimal waste". In other words, solving one of the main problems of the existing architecture.
- _Isolation_: Ensure that applications are completely separate from one another (can't read each other's data, nor learn about them through side channels). The existing solution had this property, but at high cost.
- _Performance_: A new solution should have the same or better performance as before.
- _Compatibility_: Run any binary "without code changes or recompilation". {% sidenote 'compat' "This requirement was there, even though Lambda oringally supported a small set of languages. Making a generic solution was planning for the long-term!" %}
- _Fast Switching_: "It must be possible to start new functions and clean up old functions quickly".
- _Soft Allocation_: "It must be possible to over commit CPU, memory, and other resources". This requirement impacts utilization (and in turn, the cost of the system to AWS/the customer). Overcommittment comes into play a few times during a Firecracker VM's lifetime. For example, when it starts up, it theoretically is allocated resources, but may not be using them right away if it is performing set up work. Other times, the VM may need to burst above the configured soft-limit on resources, and would need to consume those of another VM. The paper note's "We have tested memory and CPU oversubscription ratios of over 20x, and run in production with ratios as high as 10x, with no issues" - very neat!

The constraints were applied to three different categories of solutions: _Linux containers_, _language-specific isolation_, and _alternative virtualization solutions_ (they were already using virtualization, but wanted to consider a different option than their existing implementation).

### Linux containers

There are several _Isolation_ downsides to using Linux containers. 

First, Linux containers interact directly with a host OS using syscalls{% sidenote 'syscalls' "Syscalls are a standard way for programs to interact with an operating system. They're really neat. I highly reccommend [Beej's guide to Network Programming](http://beej.us/guide/bgnet/) for some fun syscall programming" %}. One can lock-down which syscalls a program can make (the paper mentions using [Seccomp BPF](https://www.kernel.org/doc/html/v4.16/userspace-api/seccomp_filter.html)), and even which arguments the syscalls can use, as well as using other security features of container systems (the Fly.io article linked above discusses this topic in more depth).

Even using other Linux isolation features, at the end of the day the container is still interacting with the OS. That means that if customer code in the container figures out a way to pwn the OS, or figures out a side channel to determine state of another container, _Isolation_ might break down. Not great.

### Language-specific isolation

While there are ways to run language-specific VMs (like the JVM for Java/Scala/Clojure or V8 for Javascript), this approach doesn't scale well to many different languages (nor does it allow for a system that can run arbitrary binaries - one of the original design goals).

### Alternative Virtualization Solutions

Revisiting virtualization led to a focus on what about the existing virtualization approach was holding Lambda back:

- _Isolation_: the code associated with the components of virtualization are lengthy (meaning more possible areas of exploitation), and [researchers have escaped from virtual machines before](https://www.computerworld.com/article/3182877/pwn2own-ends-with-two-virtual-machine-escapes.html).
- _Overhead and density_: the components of virtualization (which we will get into further down) require too many resources, leading to low utilization
- _Fast switching_: VMs take a while to boot and shut down, which doesn't mesh well with Lambda functions that need a VM quickly and may only use it for a few seconds (or less).

The team then applied the above requirements to the main components of the virtualization system: the hypervisor and the virtual machine monitor.

First, the team considered which _type_ of hypervisor to choose. There are two types of hypervisors, Type 1 and Type 2. The textbook definitions of hypervisors say that Type 1 hypervisors are integrated directly in the hardware, while Type 2 hypervisors run an operating system on top of the hardware (then run the hypervisor on top of that operating system). 

{% maincolumn 'assets/firecracker/Hypervisor.svg' 'Type 1 vs Type 2 Hypervisors. Scsami, CC0, via Wikimedia Commons' %}

Linux has a robust hypervisor built into the kernel, called [Kernel Virtual Machine](https://www.kernel.org/doc/ols/2007/ols2007v1-pages-225-230.pdf) (a.k.a. KVM) that is arguably a Type 1 hypervisor{% sidenote 'type1' "[Different resources](https://serverfault.com/questions/855094/is-kvm-a-type-1-or-type-2-hypervisor) make [different arguments](https://virtualizationreview.com/Blogs/Mental-Ward/2009/02/KVM-BareMetal-Hypervisor.aspx) for whether KVM is a Type 1 or Type 2 hypervisor." %}.

Using a hypervisor like KVM allows for kernel components to be moved into userspace - if the kernel components are in user space and they get pwned, the host OS itself hasn't been pwned. Linux provides an interface, [virtio](https://wiki.libvirt.org/page/Virtio){% sidenote 'virtio' "Fun fact: the author of the paper on virtio, Rusty Russell, is now a key developer of a main [Bitcoin Lightning implementation](https://github.com/ElementsProject/lightning)."%}, that allows the user space kernel components to interact with the host OS. Rather than passing all interactions with a guest kernel directly to the host kernel, some functions, in particular device interactions, go from a guest kernel to a _virtual machine monitor_ (a.k.a. VMM). One of the most popular VMMs is [QEMU](https://www.usenix.org/legacy/publications/library/proceedings/usenix05/tech/freenix/full_papers/bellard/bellard.pdf).
{% maincolumn 'assets/firecracker/virt.png' '' %}

Unfortunately, QEMU has a significant amount of code (again, more code means more potential attack surface), as it supports a full range of functionality - even functionality that a Lambda would never use, like USB drivers. Rather than trying to pare down QEMU, the team forked [crosvm](https://opensource.google/projects/crosvm){% sidenote 'crosvmfork' "I enjoyed [this](https://prilik.com/blog/post/crosvm-paravirt/) post on crosvm from a former Google intern."  %} (a VMM open-sourced by Google, and developed for ChromeOS), in the process significantly rewriting core functionality for Firecracker's use case. The end result was a slimmer library with only code that would conceivably be used by a Lambda - resulting in 50k lines of Rust (versus > 1.4 million lines of C in QEMU{% sidenote 'QEMU' 'Relatedly, there was an interesting [blog post](http://blog.vmsplice.net/2020/08/why-qemu-should-move-from-c-to-rust.html) about QEMU security issues and thoughts on Rust from a QEMU maintainer.' %}). Because the goal of Firecracker is to be as small as possible, the paper calls the project a _MicroVM_, rather than "VM".

## How do Firecracker MicroVMs get run on AWS?

Now that we roughly understand how Firecracker works, let's dive into how it is used in running Lambda. First, we will look at how the Lambda architecture works on a high level, followed by a look at how the running the Lambda itself works.

### High-level architecture of AWS Lambda

When a developer runs (or _Invokes_, in AWS terminology) a Lambda, the ensuing HTTP request hits an AWS Load Balancer {% sidenote 'aws' "Lambdas can also start via other events - like 'integrations with other AWS services including storage (S3), queue (SQS), streaming data (Kinesis) and database (DynamoDB) services.'"%}.

{% maincolumn 'assets/firecracker/arch.png' '' %}

There are a four main infrastructure components involved in running a Lambda once it has been invoked:

- _Workers_: The components that actually run a Lambda's code. Each worker runs many MicroVMs in "slots", and other services schedule code to be run in the MicroVMs when a customer _Invokes_ a Lambda.
- _Frontend_: The entrance into the Lambda system. It receives _Invoke_ requests, and communicates with the  _Worker Manager_ to determine where to run the Lambda, then directly communicates with the _Workers_.
- _Worker Manager_: Ensures that the same Lambda is routed to the same set of _Workers_ (this routing impacts performance for reasons that we will learn more about in the next section). It keeps tracks of where a Lambda has been scheduled previously. These previous runs correspond to "slots" for a function. If all of the slots for a function are in use, the _Worker Manager_ works with the _Placement_ service to find more slots in the _Workers_ fleet.
-  _Placement_ service: Makes scheduling decisions when it needs to assign a Lambda invocation to a _Worker_. It makes these decision in order to "optimize the placement of slots for a single function across the worker fleet, ensuring that the utilization of resources including CPU, memory, network, and storage is even across the fleet and the potential for correlated resource allocation on each individual worker is minimized".

### Lambda worker architecture

Each Lambda worker has thousands of individual _MicroVMs_ that map to a "slot". 

{% maincolumn 'assets/firecracker/lambdaworker.png' '' %}

Each MicroVM is associated with resource constraints (configured when a Lambda is setup) and communicates with several components that allow for scheduling, isolated execution, and teardown of customer code inside of a Lambda:

- _Firecracker VM_: All of the goodness we talked about earlier.
- _Shim process_: A process inside of the VM that communicates with an external side car called the _Micro Manager_.
- _Micro Manager_: a sidecar that communicates over TCP with a _Shim process_ running inside the VM. It reports metadata that it receives back to the _Placement_ service, and can be called by the _Frontend_ in order to _Invoke_ a specific function. On function completion, the _Micro Manager_ also receives the response from the _Shim process_ running inside the VM (passing it back to the client as needed).

While slots can be filled on demand, the _Micro Manager_ also starts up Firecracker VMs in advance - this helps with performance (as we will see in the next section).

## Performance

Firecracker was evaluated relative to similar VMM solutions on three dimensions: _boot times_, _memory overhead_, and _IO Performance_. In these tests, Firecracker was compared to QEMU and Intel Cloud Hypervisor{% sidenote 'crosvm' "Interestingly, Firecracker wasn't compared to crosvm. I am not sure if this is because it wasn't possible, or whether the authors of the paper thought it wouldn't be a fair comparison." %}. Additionally, there are two configurations of Firecracker used in the tests: Firecracker and Firecracker-pre. Because Firecracker MicroVMs are configured via API calls, the team tested setups where the API calls had completed (Firecracker-pre, where the "pre" means "pre-configured") or had not completed (regular Firecracker). The timer for both of these configurations ended when the _init_ process in the VM started.

### Boot times

The boot time comparisons involved two configurations: booting 500 total MicroVMs serially, and booting 1000 total MicroVMs, 50 at a time (in parallel). 

{% maincolumn 'assets/firecracker/boot_time.png' '' %}

The bottom line from these tests is that Firecracker MicroVMs boot incredibly quickly - _Fast switching_ ✅ !

### Memory overhead

Relative to the other options, Firecracker uses significantly less memory - _overhead and density_ ✅!
{% maincolumn 'assets/firecracker/mem.png' '' %}

### IO Performance

Relative to the other options, Firecracker and the comparable solution of Intel's Cloud Hypervisor didn't perform well in all tests. The paper argues that the causes of relatively inferior performance in the IO tests are no flushing to disk and an implementation of block IOs that performs IO serially - the paper notes that "we expect to fix these limitations with time". Digging into Github issues for Firecracker, I [found one](https://github.com/firecracker-microvm/firecracker/issues/1600) that indicates they were prototyping use of [io_uring](https://unixism.net/loti/what_is_io_uring.html) to support async IO (and increase IO performance).
{% maincolumn 'assets/firecracker/io.png' '' %}

## Conclusion

Firecracker was interesting to learn about because it is a high-performance, low overhead VMM written in Rust. The paper also is a great study in pragmatic technical decision making - rather than rewriting already robust software (KVM), the team focused on a specific component of an existing system to improve. Along the way, we learned about how different methods for _isolating_ customer workloads from each other {% sidenote 'bpf' "In particular, I thought seccomp-bpf was interesting and look forward to learning more about BPF/eBPF. First stop: [Julia Evans' guide](https://jvns.ca/blog/2017/06/28/notes-on-bpf---ebpf/)" %}.

If you made it this far, you probably enjoyed the paper review - I post them on my [Twitter](https://twitter.com/micahlerner) every week!