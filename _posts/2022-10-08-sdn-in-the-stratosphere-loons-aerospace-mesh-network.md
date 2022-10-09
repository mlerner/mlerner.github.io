---
layout: post
title: "SDN in the Stratosphere: Loon’s Aerospace Mesh Network"
categories:
---

[SDN in the Stratosphere: Loon’s Aerospace Mesh Network](https://dl.acm.org/doi/10.1145/3544216.3544231)

## What is the research?

This paper is about the networking technology behind [Loon](https://x.company/projects/loon/), a project that aimed to provide internet connectivity via a network of balloons in low-earth orbit{% sidenote 'leo' "NASA has an [interesting article](https://www.nasa.gov/leo-economy/faqs) on commercializing the low-earth orbit (LEO)."%}. The project took the unique approach of relying on balloons to provide internet access in remote areas or as part of disaster response (when internet services otherwise might not be available). Founded in 2011, the project successfully created mesh networks{% sidenote 'mesh' "Mesh networks rely on connections between nodes in order to achieve connectivity." %} covering thousands of kilometers, using devices deployed into harsh conditions for up to three hundred days at a time.

{% maincolumn 'assets/loon/figure1.png' '' %}

Along the way, Loon tackled unique technical challenges not faced by existing mesh networks{% sidenote 'prev' "For example, [NYC Mesh](https://www.nycmesh.net/), new coverage [here](https://www.nytimes.com/2021/07/16/nyregion/nyc-mesh-community-internet.html)."%}. For example, the system needed to provide networking capabilities in the face of changing conditions (including challenges like weather, balloon drift, and interference from geological features).

To solve these problems, the project implemented a _Software Defined Network (SDN)_ that was capable of anticipating issues and modifying network structure accordingly. While _Software Defined Networks_ are widely used in industry{% sidenote 'sdn' "Computerphile has [a helpful video](https://www.youtube.com/watch?v=Nh2hXUuKXyQ&t=306s) on what exactly _Software Defined Networking_ is. [OpenFlow](https://dl.acm.org/doi/10.1145/1355734.1355746) was a historic paper on the subject, and the [B4 project at Google](https://cseweb.ucsd.edu//~vahdat/papers/b4-sigcomm13.pdf) is a well known deployment of the approach."%}, a primary difference in Loon's approach is integrating time and geospatial factors in decision-making. Integrating these factors was critical to providing connectivity while balloons were moving in the sky - as a result, the authors call their implementation a _Temporal-Spatial Software Defined Network_ (_TS-SDN_).

{% maincolumn 'assets/loon/figure2.png' '' %}

Loon ended in 2021{% sidenote 'shutdown' "See article [here](https://www.nytimes.com/2021/01/21/technology/loon-google-balloons.html)."%}, and the authors open-sourced other artifacts in addition to publishing this paper{% sidenote 'artifacts' "See [the Loon Library](https://x.company/projects/loon/the-loon-collection/)"%}. While the cost of deploying satellites dropped dramatically{% sidenote 'cost' 'According to [published data](https://www.nbcnews.com/science/space/space-launch-costs-growing-business-industry-rcna23488), "Companies that once had to pay hundreds of thousands of dollars to put a satellite into orbit can now do the same for a fraction of that price."'%} since Loon's initial development (potentially obviating the need for balloons in the sky), the design, implementation, and learnings from the project can hopefully influence other systems deployed in similarly harsh and changing environments{% sidenote 'spacex' "Recently, projects like Spacex's [Starlink](https://www.starlink.com/) and [Astranis](https://www.astranis.com/) are deploying constellations of moving satellites."%}.

## What are the paper's contributions?

The paper makes three main contributions:

- Documentation of the challenges and tradeoffs that went into the design of the SDN.
- A description of the system's architecture.
- Performance metrics and evaluation using metrics from Loon's production deployment.

## How does the system work?

The paper is primarily about Loon's unique approach to shaping network structure. The authors call their approach a _Temporal Spatial Software Defined Network (TS-SDN)_, as it adapted a widely-used industry pattern, the _Software Defined Network (SDN)_{% sidenote 'intro' "The intro section includes a link to a few resources with more information about this pattern."%}, to the project's unique constraints (which are primarily defined by using ballooons). In particular, Loon's SDN considered the impact of time (temporal) and balloon positioning (spatial) on how to structure the network.

### Challenges

While there are successful industry deployments of SDNs at scale, Loon faced unique constraints due to the project's reliance on balloons:

- _Navigation_: the balloons moved based on where weather conditions pushed them, creating uncertainty in their future positions. A network based on balloons needed to anticipate future positions, and reconfigure the network in anticipation of problems.
- _Power_: solar energy powered the balloons (which had small onboard batteries). As a result, the network could only operate when there was sufficient sun (limiting use to the daytime). The network effectively shut down over night, and reconfigured/bootstrapped everyday.
- _Radio links_: the balloons used radios to build a network with one another and with dedicated ground stations, although weather often impacted these links{% sidenote 'radio' "The paper cites [Impact of rain attenuation on 5G millimeter wave communication systems in equatorial Malaysia investigated through disdrometer data](https://ieeexplore.ieee.org/document/7928616)."%}. Furthermore, balloon communication with ground stations required line of sight, meaning that topographical features (like mountains) impacted the network.
- _Command & Control_: Loon needed to remotely configure balloons given changing positions, limited power, and weather/topographical challenges to radio communications. Relying on one mode of communication would limit options for controlling balloons. To improve the reliability of balloon control, the project relied on ground stations and _two types of satellite links_ for communication with balloons in the air.

### Loon Architecture

{% maincolumn 'assets/loon/figure3.png' '' %}

Loon implemented solutions to the challenges above by dividing the system into five main components{% sidenote 'six' "Not included in this count is a mobile network operator that provides access to [their network](https://archive.ph/87uHa)."%}:

- _Balloons_: the nodes in the network. Users connect to the balloons, and their traffic flows to its destination over higher-bandwidth lines.
- _Satellites_: used to bootstrap the network. These communications had limited bandwidth and high latency{% sidenote 'bw' 'The paper notes that, "To avoid channel overload we typically were limited to sending less than one 1 KiB message per minute per balloon with multi-minute one-way latency."'%}.
- _Remote data centers_: these contain a gateway that the _TS-SDN_ uses to issue commands to balloons (when bootstrapping the network, or issuing commands that otherwise can't reach balloons via other means) .
- _Edge compute_: owned data centers that acted as a central hub, hosting various system components.
- _Ground stations_: remotely deployed infrastructure that balloons connected to for the majority of their networking needs.

Loon's _TS-SDN_ divided the system into separate _control_ and _data_ planes{% sidenote 'separate' 'Many systems are divided into a _control plane_ (which controls or programs system components) and a _data plane_ (which contains components that do a thing, like forwarding packets). Separation of these two concerns can simplify responsibilities of system components, increase reliability, and allow independent scaling. For example, this separation could allow an implementer to specify that data plane components continue operating even if the control plane fails (this behavior is often called ["fail open"](https://blogs.keysight.com/blogs/tech/nwvs.entry.html/2020/05/20/fail_closed_failop-ZYAt.html).'%}.

_Control planes_ are often responsible for computing and propagating configuration. Every day, the control plane of the _TS-SDN_ effectively reset, as balloons powered down due to battery constraints. That meant that on a recurring basis, the control plane re-established contact with balloons, likely via satellite communication. After bootstrapping, the SDN programmed a balloon's networking device to connect to nearby ground stations or other already-bootstrapped balloons. After this initial setup, control-plane configuration flowed through the network via _Ad hoc On-Demand Distance Vector Routing (AODV)_{% sidenote 'aodv' "The original paper on [AODV](https://ebelding.cs.ucsb.edu/sites/default/files/publications/wmcsa99.pdf) won a SIGCOMM [Test of Time award in 2018](https://www.sigmobile.org/grav/awards/test-of-time-paper)."%}, an approach to routing in mesh networks that requires no centralized coordinator{% sidenote 'manet' "There are multiple approaches to routing in mobile networks - in the appendix, the paper cites [Destination-Sequenced Distance-Vector Routing](https://www.cse.iitb.ac.in/~mythili/teaching/cs653_spring2014/references/dsdv.pdf) and [Optimized Link State Routing Protocol](https://ieeexplore.ieee.org/document/995315)."%}.

_Data planes_ handle connectivity and packet routing - in Loon's implementation, the control plane configured the data plane by sending messages that change networking equipment behavior. The data plane also needed to quickly reconfigure when it received instructions (otherwise, geographical features and weather would impact network performance and reliability).

### Modeling the Network

The _TS-SDN_ reconfigured the data plane by consuming data on changing conditions, then issuing commands to balloons via the control plane. Three main types of inputs influenced the system's decision making: _physical model_, _logical model_, _network management information_.

{% maincolumn 'assets/loon/figure5.png' '' %}

The _physical model_ contains factors like:

- _Motion and orientation_: where are the balloons in the air, and where are they going?
- _Weather conditions_: rain was particularly troublesome to balloon radio. As a result, realtime data from ground stations (close to the balloons), and delayed forecasts{% sidenote 'forecasts' "The paper cites using [ECMWF forecasts](https://www.ecmwf.int/en/forecasts), which are published with various frequencies - several weather apps contain [details](https://windy.app/blog/what-is-ecmwf-weather-forecast-model.html) on their model. Metereology is also an [interesting area of high-performance computing](https://events.ecmwf.int/event/169/timetable/) that could be a future paper review topic."%} influenced the _TS-SDN_'s predictions by helping it decide which connections between balloons it should make or break.
- _Platform definitions_: what hardware do the balloons have on board? This influences a balloon's connectivity in the network.

The _network model_ primarily stored information on the state of the network, like current connectivity. This metadata reduced churn in the network, as the _TS-SDN_ could calculate which configuration messages it didn't need to send (as their state was already represented in the network). Additionally, knowledge of network structure allowed the TS-SDN to make alterations that increased reliability - for example, adding multiple paths to the same balloon.

Lastly, _network management information_ represented input from admins (explicit instructions for the TS-SDN to modify the network structure), as well as connectivity requests containing "source and destination platforms and desired bitrate".

### Reconfiguring the Network

The _TS-SDN_ ingested the above datasources, then calculated the desired future state of the network in a multi-step process.

First, the _TS-SDN_ used elements of the _physical model_ to identify _candidate links_ - in other words, potential connectivity between different components of the network that could theoretically exist. Next, it compared these candidates with both the current state of the network (represented as the _network model_), and with network administrative actions. This comparison produced a set of _intents_ representing the state that the network should converge to in the future{% sidenote "intent" "The concept of intents shows up in SDNs, like [Orion: Google’s Software-Defined Networking Control Plane](https://www.usenix.org/system/files/nsdi21-ferguson.pdf) and the [Open Network Operating System (ONOS) SDN Controller](https://opennetworking.org/onos/)."%}. The SDN then _actuated_ intents on the _control-data-plane interface (CDPI)_, sending out configuration messages to ground stations and balloons.

The paper notes the complexity in this last step of control plane messaging, specifically around _balloon reachability_ and _time to enactment_ of configuration changes.

Balloon reachability mattered for the _TS-SDN_, as unreachable balloons would not reconfigure themselves to resolve networking issues (leading to poorly routed traffic, dropped packets, and a bad user experience). To limit this problem, the system transmitted control plane messages via satellite or ground station paths based on continuously gathered metadata on a balloon's reachability.

The _TS-SDN_ also measured _time to enactment_, which represented the delay for a balloon to implement a desired re-configuration. The paper notes it was:

> critical for maintaining mesh connectivity and an in-band control plane. As the position of nodes and the viability of links changes, nodes need to converge quickly on a new topology and new routing paths. However, control plane messages may reach nodes at different times, causing some nodes to switch to the new topology while others remain in the old.

## How is the research evaluated?

Throughout the paper, the authors share information on how the Loon system worked in production. Specifically, the evaluation considers the TS-SDN's ability to achieve node reachability, to recover in the face of failure, and to enact intents.

The research measures node reachability by keeping track of whether different components of the system were usable. The different layers of the network relied on each other, impacting their availability - for example, a balloon wouldn't transmit packets (via the data plane) if it wasn't configured to do so (via the control plane). The link layer had the highest reachability (given its low level in the system), although the paper mentions that improvements to the TS-SDN, like increasing the number of redundant links in the network, allowed for a highly reliable control plane layer to exist on top of a sometimes unreliable link layer.

{% maincolumn 'assets/loon/figure6.png' '' %}

To evaluate recovery in the face of failure, the paper compares the number of intended links to established links while varying the redundancy of the mesh network. In a mesh network with low numbers of redundant links, there is a disconnect between the TS-SDN's intention and what it is able to actuate, as control plane messages do not successfully propagate. Failure recovery to re-establish links (and forward messages) also takes longer because the network performed recovery via a satellite link (costly with respect to latency). In a highly redundant network structure, there is little gap between intention and actuation, as the control plane messages route around failed links.

{% maincolumn 'assets/loon/figure7.png' '' %}

The paper also visualizes the time to enactment for intents using different routes. In particular, it is clear that relying on satellite (SatCom) to enact intents is significant slower than relying on communication between the different nodes in the network.

{% maincolumn 'assets/loon/figure9.png' '' %}

## Conclusion

The paper on Loon's _TS-SDN_ approaches the idea of Software Defined Networks from a unique angle. Along the way, the research also has several general takeaways.

First, the Loon SDN ran into debugging challenges that align with problems faced by other distributed systems. The paper's authors discuss their approach to debugging why and how the system reached a specific state, focusing on discerning "_correct_ system behavior versus _bugs_".

The research also covers concrete examples of the trade-offs between explainability and computational power. One case discussed by the paper is choosing a less-complex solver to make decisions about network structure, rather than a more complex (and less understandable) approach.

Last but not least, the authors explain the impact of datasource choice on the SDN's predictions. For example, the solver's initial design made predictions based on sometimes out-of-date weather data, leading to network structures that performed poorly. While this more advanced approach _should have worked_, in practice its performance was lacking. Based on these findings, the solver evolved to rely on direct measurements of network performance, optimizing for improving the user experience (rather than relying on a more distant metric).
