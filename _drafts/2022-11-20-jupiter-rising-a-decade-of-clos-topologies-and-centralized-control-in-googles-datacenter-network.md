---
layout: post
title: "Jupiter Rising: A Decade of Clos Topologies and Centralized Control in Google’s Datacenter Network"
categories:
---

[Jupiter Rising: A Decade of Clos Topologies and Centralized Control in Google’s Datacenter Network](https://dl.acm.org/doi/10.1145/2829988.2787508)

## What is the research?

The paper, _Jupiter Rising: A Decade of Clos Topologies and Centralized Control in Google's Datacenter Network_, discusses the design and evolution of Google's datacenter network. In particular, the paper talks about how the network scaled to provide high-speed connectivity and efficient resource allocation under increasing demand.

At the time that the authors initially started their work, the network structure of many data centers relied on large, expensive switches with limited routes between machines in the data center. Because many machines needed to share few routes, communication between machines could quickly overload the networking equipment. As a result, resource intensive applications were often co-located inside of a datacenter, leading to pockets of underutilized resources.

{% maincolumn 'assets/jupiter/before.png' 'Before the fabric, the data center network had diminishing bandwidth the farther away a machine was trying to reach.' %}

Two factors were critical to scaling: reshaping the structure of the network using Clos topologies{% sidenote 'clos' "There is a great deep dive on the inner workings of _Clos topologies_ [here](https://archive.ph/jS9ko)."%} and configuring switches using centralized control. While both of these techniques were previously described in research, this paper covers their implementation and use at scale.

The paper also discusses the challenges and limitations of the design and how Google has addressed them over the past decade. Beyond the scale of their deployment{% sidenote 'scale' 'The authors note that the, "datacenter networks described in this paper represent some of the largest in the world, are in deployment at dozens of sites across the planet, and support thousands of internal and external services, including external use through Google Cloud Platform."'%}, the networks described by the paper continue to influence the design of many modern data center networks{% sidenote 'atscale' "See [Meta's](https://engineering.fb.com/2014/11/14/production-engineering/introducing-data-center-fabric-the-next-generation-facebook-data-center-network/), [LinkedIn's](https://engineering.linkedin.com/blog/2016/03/project-altair--the-evolution-of-linkedins-data-center-network), and [Dropbox's](https://dropbox.tech/infrastructure/the-scalable-fabric-behind-our-growing-data-center-network) descriptions of their fabrics."%}.

## What are the paper's contributions?

The paper makes three main contributions to the field of datacenter network design and management:

- A detailed description of the design and evolution of Google's datacenter network, including the use of Clos topologies and centralized control.
- An analysis of the challenges and limitations of this network design, and how Google has addressed them over the past decade.
- An evaluation of the approach based on production outages and other experiences.

## Design Principles

Spurred on by growing cost and operational challenges of running large data center networks, the authors of the paper explored alternative designs.

In creating these designs, they drew on three main principles: _basing their design on Clos topologies_, _relying on merchant silicon_{% sidenote 'merchant' 'The paper describes merchant silicon as, "general purpose commodity priced, off the shelf switching components". See article on [Why Merchant Silicon Is Taking Over the Data Center Network Market](https://www.datacenterknowledge.com/networks/why-merchant-silicon-taking-over-data-center-network-market).'%}, and _using centralized control protocols_.

_Clos topologies_ are a network design{% sidenote 'sigcomm' "Laid out in [A Scalable, Commodity Data Center Network Architecture](https://cseweb.ucsd.edu/~vahdat/papers/sigcomm08.pdf)."%} that consists of multiple layers of switches, with each layer connected to the other layers. This approach increased network scalability and reliability by introducing more routes to a given machine, increasing bandwidth while reducing the impact of any individual link's failure on reachability.

{% maincolumn 'assets/jupiter/trad.png' 'From [A Scalable, Commodity Data Center Network Architecture](http://ccr.sigcomm.org/online/files/p63-alfares.pdf)' %}
{% maincolumn 'assets/jupiter/fattree.png' 'From [A Scalable, Commodity Data Center Network Architecture](http://ccr.sigcomm.org/online/files/p63-alfares.pdf)' %}

A design based on _Clos topologies_ threatened to dramatically increase cost, as they contained more hardware than previous designs - at the time, many networks relied on a small number of expensive, high-powered, and central switches. To tackle this issue, the system chose to _rely on merchant silicon_ tailored in-house to address the unique needs of Google infrastructure. Investing in custom in-house designs paid off{% sidenote 'offset' "This investment was also offset by not spending resources on expensive switches."%} in the long term via a higher pace of network hardware upgrades.

Lastly, the network design pivoted towards _centralized control_ over switches, as growing numbers of paths through the network increased the complexity and difficulty of effective traffic routing. This approach is now commonly known as _Software Defined Networking_, and is covered by further papers on Google networking{% sidenote 'orion' "For example, [Orion: Google's Software-Defined Networking Control Plane](https://www.usenix.org/conference/nsdi21/presentation/ferguson)."%}.

## Network Evolution

The paper describes five main iterations of networks developed using the principles above: _Firehose 1.0_,  _Firehose 1.1_, _Watchtower_, _Saturn_, and _Jupiter_.

_Firehose 1.0_ was the first iteration of the project and introduced a multi-tiered network aimed at delivering 1G speeds between hosts. The tiers were made up of:

- _Spine blocks_: groups of switches used to connect the different layers of the network, typically making up the core.
- _Edge aggregation blocks_: groups of switches used to connect a group of servers or other devices to the network, typically located near servers.
- _Top-of-rack switches_: switches directly connected to a group of machines physically in the same rack (hence the name).

{% maincolumn 'assets/jupiter/figure2.png' '' %}

_Firehose 1.0_ never reached production for several reasons, one of which being that the design placed the networking cards alongside servers. As a result, server crashes disrupted connectivity.

_Firehose 1.1_  improved on the original design by moving the networking cards originally installed alongside servers into separate enclosures. The racks were then connected using copper cables.

{% maincolumn 'assets/jupiter/figure6.png' '' %}
{% maincolumn 'assets/jupiter/figure7.png' '' %}

_Firehose 1.1_ was the first production Clos topology deployed at Google. To limit the risk of deployment, it was configured as a "bag on the side" alongside the existing network. This configuration allowed servers and batch jobs to take advantage of relatively fast intra-network speeds for internal communication{% sidenote "mr" "For example, in running [MapReduce](https://static.googleusercontent.com/media/research.google.com/en//archive/mapreduce-osdi04.pdf), a seminal paper that laid the path for modern 'big data' frameworks."%}, while using the relatively slower existing network for communication with the outside world. The system also successfully delivered 1G intranetwork speeds between hosts, a significant improvement on the pre-Clos network.

{% maincolumn 'assets/jupiter/figure8.png' '' %}

The paper describes two versions (_Watchtower_ and _Saturn_) of the network between _Firehose_ and _Jupiter_ (the incarnation of the system at the paper's publication). _Watchtower_ (2008) was capable of 82Tbp bisection bandwidth{% sidenote 'bisection' "Bisection bandwidth represents the bandwidth between a network between two partitions in a network, and represents what the bottlenecks would be for networking performance. See description of bisection bandwidth [here](https://en.wikipedia.org/wiki/Bisection_bandwidth)."%} due to faster networking chips and reduced cabling complexity (and cost) between and among switches. _Saturn_ arrived in 2009 with newer merchant silicon and was capable of 207 Tbps bisection bandwidth.

{% maincolumn 'assets/jupiter/table3.png' '' %}

_Jupiter_ aimed to support significantly more underlying machines with a larger network fabric. Unlike previous iterations running on a smaller scale, the networking components of the fabric would be too costly (and potentially impossible) to upgrade all-at-once. As such, the newest generation of the fabric was explictly designed to support networking hardware with varying capabilities - upgrades to the infrastructure would introduce newer, faster hardware. The building block of the network was the _Centauri_ chassis, combined in bigger and bigger groups to build _aggregation blocks_ and _spine blocks_.

{% maincolumn 'assets/jupiter/figure13.png' '' %}

## Centralized Control

The paper also discusses the decision of implementing traffic routing in the Clos topology via centralized control. Traditionally, networks had used decentralized routing protocols to route traffic{% sidenote 'isis' "In particular, the paper cites IS-IS and OSPF. The protocols are [fairly similar](https://nsrc.org/workshops/2017/ubuntunet-bgp-nrens/networking/nren/en/presentations/08-ISIS-vs-OSPF.pdf), but I found [this podcast](https://packetpushers.net/podcast/show-89-ospf-vs-is-is-smackdown-where-you-can-watch-their-eyes-reload/) on the differences between the two to be useful."%}. In these protocols, switches independently learn about state and make their own decision about how to route traffic{% sidenote 'linkstate' "See [this site](https://www.computer-networking.info/principles/linkstate.html) on link-state routing for more information."%}.

For several reasons, the authors chose not to use these protocols:

- Insufficient support for [equal-cost multipath](https://en.wikipedia.org/wiki/Equal-cost_multi-path_routing) (ECMP) forwarding, a technology that allows individual packets to take several paths through the network, and was critical for taking advantage of Clos topologies.
- No high-quality, open source projects to build on (which now exist via projects from the [OpenNetworkingFoundation](https://opennetworking.org/onf-sdn-projects/))
- Existing approaches{% sidenote 'ospfareas' 'In particular, the paper talks about [OSPF Areas](http://www.rfc-editor.org/rfc/rfc2328.txt), a design for splitting up a network into different _areas_, running OSPF in each, and routing traffic between the areas. The paper also references a rebuttal to the [idea](https://datatracker.ietf.org/doc/html/draft-thorup-ospf-harmful-00), called _OSPF Areas Considered Harmful_, that demonstrates several situations in which the routing protocol would result in worse routes.'%} were difficult to scale and configure.

Instead, the paper describes Jupiter's implementation of configuring switch routing, called _Firepath_. _Firepath_ controls routing in the network by implementing two main components: _clients_ and _masters_. _Clients_ run on individual switches in the network. On startup, each switch loads a hardcoded configuration of the connections in the network, and begins recording its view based on traffic it sends and receives.

{% maincolumn 'assets/jupiter/figure18.png' '' %}

The _clients_ periodically sync their local state of the network to the _masters_, which build a _link state database_ representing the global view. _Masters_ then periodically sync this view down to _clients_, who update their networking configuration in response.

## Experiences

The paper also describes real world experiences and describes outages from building _Jupiter_ and its predecessors.

The experiences described by the paper mainly focus on network congestion, which occurred because of:

- Bursty traffic
- Limited buffers{% sidenote 'apnic' "APNIC has a great description of buffers [here](https://blog.apnic.net/2019/12/12/sizing-the-buffer/)."%} in the switches, meaning that they couldn't store significant data.
- The network being "oversubscribed", meaning that all machines that could use capacity wouldn't actually be using it at the same time.
- Imperfect routing during network failures and traffic bursts

To solve these problems, the team implemented network [Quality of Service](https://study-ccna.com/quality-of-service-qos/), allowing it to drop low-priority traffic in congestion situations. The paper also discusses using [Explicit Congestion Notification](https://www.rfc-editor.org/rfc/rfc3168), a technique for routers to signal that they are getting close to a point at which they will not be able to accept additional packets. The authors also cite [Data Center TCP](https://people.csail.mit.edu/alizadeh/papers/dctcp-sigcomm10.pdf), an approach to providing feedback built on top of ECN. By combining the two approaches, the fabric is able to achieve a 100x improvement in network congestion{% sidenote 'aggregate' "This is mentioned in the author's [talk](https://vimeo.com/175248736). From the talk, it isn't clear if they also used other techniques alongside these two."%}.

The paper describes several outages grouped into themes.

The first is related to _control software problems at scale_, where a power event restarted the switches in the network at the same time, forcing the control software into a previously untested state from which it was incapable of functioning properly (without direct interaction).

A second category is _aging hardware exposing previously unhandled failure modes_, where the software was vulnerable to failures in the core network links{% sidenote 'failslow' "This reminds me of the paper [Fail-Slow at Scale: Evidence of Hardware Performance Faults in Large Production Systems](https://www.usenix.org/conference/fast18/presentation/gunawi)!"%}, impacting the ability of components to interact with the _Firepath_ masters. As a result, networking equipment would use out of date network state to route traffic (potentially forwarding it on a route that no longer existed).

## Conclusion

The original Jupiter paper discusses several evolutions of Google's networking infrastructure, documenting the false starts, failures, and successes of one of the biggest production networks in the world. The paper also provides an interesting historical persective on adapting ideas from research in order to scale a real production system{% sidenote 'scalable' "For example, [A scalable, commodity data center network architecture](https://dl.acm.org/doi/10.1145/1402946.1402967)."%}. I particularly enjoyed{% sidenote 'outages' "As always!"%} the papers descriptions of outages and the efforts to reduce congestion using (at the time) novel technologies like DCTCP{% sidenote 'homa' "Which is somewhat similar to a previous paper review on [Homa](https://www.micahlerner.com/2021/08/15/a-linux-kernel-implementation-of-the-homa-transport-protocol.html)."%}

At SIGCOMM 2022, the team published research expanding on the original design, and discuss further evolutions beyond Clos topologies{% sidenote 'sigcomm' "See the blog [here](https://cloud.google.com/blog/topics/systems/the-evolution-of-googles-jupiter-data-center-network) and the paper [here](https://dl.acm.org/doi/10.1145/3544216.3544265)."%} - I hope to read this in a future paper review!