---
layout: post
title: "SDN in the Stratosphere: Loon’s Aerospace Mesh Network"
categories:
---

[SDN in the Stratosphere: Loon’s Aerospace Mesh Network](https://dl.acm.org/doi/10.1145/3544216.3544231)

## What is the research?

Loon was a project to provide internet connectivity via a network of balloons in low-earth orbit{% sidenote 'leo' "NASA has an [interesting article](https://www.nasa.gov/leo-economy/faqs) on commercializing the low-earth orbit (LEO)."%}. Founded in 2011, the project successfully created mesh networks{% sidenote 'mesh' "Mesh networks are a type of networking that relies on connections between nodes in order to achieve connectivity. The Loon project had the added complexity of forming networking links between moving objects." %} covering thousands of kilometers, using devices deployed into harsh conditions for up to three hundred days at a time. While the project shut down in 2021{% sidenote 'shutdown' "See article [here](https://www.nytimes.com/2021/01/21/technology/loon-google-balloons.html)."%}, the authors open-sourced important artifacts{% sidenote 'artifacts' "See [the Loon Library](https://x.company/projects/loon/the-loon-collection/)"%}.

{% maincolumn 'assets/loon/figure1.png' '' %}

One of the primary goals of Loon was providing networking capabilities in the face of changing conditions (including challenges like weather, balloon drift, and interference from geological features). To fulfill this goal, the project implemented a variation on a _Software Defined Network (SDN)_ to anticipate and modify network structure as needed. While while _Software Defined Networks_ are widely used in industry{% sidenote 'sdn' "Computerphile has [a helpful video](https://www.youtube.com/watch?v=Nh2hXUuKXyQ&t=306s) on what exactly _Software Defined Networking_ is. [OpenFlow](https://dl.acm.org/doi/10.1145/1355734.1355746) was a historic paper on the subject, and the [B4 project at Google](https://cseweb.ucsd.edu//~vahdat/papers/b4-sigcomm13.pdf) is a well known deployment of the approach."%}, a critical difference in Loon's approach is integrating time and geospatial factors in decision making in order to provide connectivity while balloons are moving in the sky - as a result, the authors call their implementation a _Temporal-Spatial Software Defined Network_ (_TS-SDN_).

{% maincolumn 'assets/loon/figure2.png' '' %}

While the cost of deploying satellites dropped dramatically{% sidenote 'cost' 'According to [published data](https://www.nbcnews.com/science/space/space-launch-costs-growing-business-industry-rcna23488), "Companies that once had to pay hundreds of thousands of dollars to put a satellite into orbit can now do the same for a fraction of that price."'%} since Loon's initial development, the design, implementation, and learnings from the project can hopefully influence other systems deployed in similarly harsh and changing environments{% sidenote 'spacex' "Recently, projects like Spacex's [Starlink](https://www.starlink.com/) and [Astranis](https://www.astranis.com/) are deploying constellations of moving satellites."%}.

## What are the paper's contributions?

The paper makes three main contributions:

- Documentation of the challenges and tradeoffs that went into the design of the SDN.
- A description of the system's architecture.
- Performance metrics and evaluation using metrics from Loon's production deployment.

## How does the system work?

The main goal of a _Software Defined Network (SDN)_ is to program devices on a network so that they can continuously provide network connectivity with minimal interruption.

### Challenges

While SDNs are successfully deployed at scale in industry, Loon faced unique constraints due to the project's reliance on balloons:

- _Navigation_: the balloons move based on where weather conditions push them, creating uncertainty in their future positions. A network based on balloons needs to anticipate future positions, and reconfigure the network in anticipation of problems.
- _Power_: balloons were powered by solar energy (with small onboard batteries). As a result, the network can only operate when there is sufficient sun (limiting use to the daytime). The network effectively shuts down over night, and reconfigures/bootstraps everyday.
- _Radio links_: the balloons use radios to build a network with one another and with dedicated ground stations, although weather often impacted these links{% sidenote 'radio' "The paper cites [Impact of rain attenuation on 5G millimeter wave communication systems in equatorial Malaysia investigated through disdrometer data](https://ieeexplore.ieee.org/document/7928616)."%}. Furthermore, balloon communication with ground stations required line of sight, meaning that topographical features (like mountains) impacted the network.
- _Command & Control_: Loon needed to remotely configure balloons given changing positions, limited power, and weather/topographical challenges to radio communications. To improve the reliability of balloon control, the project relied on ground stations and _two types of satellite links_ for communication with balloons in the air.

### Loon Architecture

{% maincolumn 'assets/loon/figure3.png' '' %}

The system implemented solutions to the challenges above using five main components{% sidenote 'six' "Not included in this count is a mobile network operator that provides access to [their network](https://archive.ph/87uHa)."%}:

- _Balloons_: the nodes in the network. Users connect to the balloons, and their traffic flows to its destination over higher-bandwidth lines.
- _Satellites_: used to bootstrap the network. These communications had limited bandwidth and high latency{% sidenote 'bw' 'The paper notes that, "To avoid channel overload we typically were limited to sending less than one 1 KiB message per minute per balloon with multi-minute one-way latency."'%}.
- _Remote data centers_: these contain a gateway that the _TS-SDN_ uses to issue commands to balloons (when bootstrapping the network, or issuing commands that otherwise can't reach balloons via other means) .
- _Edge compute_: owned data centers that acted as a central hub, hosting various system components.
- _Ground stations_: remotely deployed infrastructured that balloons connected to for the majority of their networking needs.

Loon divides the system into separated _control_ and _data_ planes{% sidenote 'separate' "Many systems are divided into a _control plane_ (which controls or programs system components) and a _data plane_ (which contains components that do a thing, like forwarding packets). Separation of these two concerns can simplify responsibilities of system components, increase reliability, and allow independent scaling. For example, this separation could allow an implementer to specify that data plane components continue operating even if the control plane fails (this behavior is often called ["fail open"](https://blogs.keysight.com/blogs/tech/nwvs.entry.html/2020/05/20/fail_closed_failop-ZYAt.html)."%}.

_Control planes_ are often responsible for configuring networking equipment. The control plane of the _TS-SDN_ performed this function using satellite links to bootstrap balloons onto the network. After bootstrapping, the SDN programs a balloon's networking device to connect to nearby ground stations or other already-bootstrapped balloons. After this initial setup, control-plane configuration flowed through the network via _Ad hoc On-Demand Distance Vector Routing (AODV)_, an approach to routing in mesh networks{% sidenote 'manet' "There are multiple approaches to routing in mobile networks - the paper cites [research](https://blogs.keysight.com/blogs/tech/nwvs.entry.html/2020/05/20/fail_closed_failop-ZYAt.html) on the performance of different approaches."%}.

_Data planes_ handle connectivity and packet routing - in Loon's implementation, the control plane configures the data plane by sending messages that change networking equipment behavior. The data plane needs to be capable of reconfiguring when it receives instructions. Otherwise, geographical features and weather would impact network performance and reliability.

### Modeling the Network

The _TS-SDN_ reconfigures the data plane by consuming data on changing conditions, then issuing commands to balloons via the control plane. Three main types of inputs influence the system's decision making: _physical model_, _logical model_, _network management information_.

{% maincolumn 'assets/loon/figure5.png' '' %}

The _physical model_ contains factors like:

- _Motion and orientation_: where are the balloons in the air, and where are they going?
- _Weather conditions_: rain was particularly troublesome to balloon radio. As a result, realtime data from ground stations (close to the balloons), and delayed forecasts{% sidenote 'forecasts' "The paper cites using [ECMWF forecasts](https://www.ecmwf.int/en/forecasts), which are published with various frequencies - several weather apps contain [details](https://windy.app/blog/what-is-ecmwf-weather-forecast-model.html) on their model. Metereology is also an [interesting area of high-performance computing](https://events.ecmwf.int/event/169/timetable/) that could be a future paper review topic."%} influenced the _TS-SDN_'s predictions by helping it decide which connections between balloons it should make or break.
- _Platform definitions_: what hardware do the balloons have on board? This influences a balloon's connectivity in the network.

The _network model_ primarily stores information on the state of the network, like current connectivity. This metadata can be helpful for reducing churn in the network, as the _TS-SDN_ could calculate which configuration messages it doesn't need to send (as their state was already represented in the network). Additionally, knowledge of network structure allows the TS-SDN to make alterations that increase reliability - for example, adding multiple paths to the same balloon.

Lastly, _network management information_ represented input from admins (explicit instructions for the TS-SDN to modify the network structure), as well as connectivity requests containing "source and destination platforms and desired bitrate".


### Reconfiguring the Network

The _TS-SDN_ ingested the above datasources, then calculated the desired future state of the network in a multi-step process.

First, the _TS-SDN_ used elements of the _physical model_ to identify _candidate links_ - in other words, potential connectivity between different components of the network that could theoretically exist. Next, it combined these candidates with the current state of the network (represented as the _network model_), and network administrative actions to produce a set of _intents_ representing the state that the network should converge to in the future{% sidenote "intent" "The concept of intents shows up in SDNs, like [Orion: Google’s Software-Defined Networking Control Plane](https://www.usenix.org/system/files/nsdi21-ferguson.pdf) and the [Open Network Operating System (ONOS) SDN Controller](https://opennetworking.org/onos/)."%}. The SDN then _actuated_ intents on the _control-data-plane interface (CDPI)_, sending out configuration messages to ground stations and balloons.

The paper notes the complexity in this last step of control plane messaging, specifically around _balloon reachability_ and _time to enactment_ of configuration changes.

Balloon reachability mattered for the _TS-SDN_, as unreachable balloons would not reconfigure themselves to resolve networking issues (leading to incorrectly routed traffic and a bad user experience). To ensure reliable reconfiguration, the system transmitted control plane messages via satellite and ground station paths. Furthermore, the system would decide which path to use based on continuously gathered metadata on a balloon's reachability.

The _TS-SDN_ also measured _time to enactment_, which represents the delay for a balloon to implement a desired re-configuration. The paper notes it was:

> critical for maintaining mesh connectivity and an in-band control plane. As the position of nodes and the viability of links changes, nodes need to converge quickly on a new topology and new routing paths. However, control plane messages may reach nodes at different times, causing some nodes to switch to the new topology while others remain in the old.

## How is the research evaluated?

Throughout the paper, the authors share information on how the Loon system worked in production. Specifically, the evaluation considers the TS-SDN's ability to achieve node reachability, to recover in the face of failure, and to enact intents.

The research measures node reachability by keeping track of whether different types of communication in the system are usable. The link layer had the highest reachability, although improvements to the TS-SDN (in particular, increasing the number of redundant links in the network) allowed for a highly reliable control plane layer to exist on top of the more unreliable system.

{% maincolumn 'assets/loon/figure6.png' '' %}

To evaluate recovery in the face of failure, the paper includes information on the number of redundant links it intended, compared to those it established. While there is some disconnect between the TS-SDN's intention and what it is able to actuate, the mesh redundancy that the system *does* achieve allows node reconfiguration without falling back to a satellite link (which would be very costly with respect to latency). The speed of recovery shows up in the system's time to repair broken links.

{% maincolumn 'assets/loon/figure7.png' '' %}
{% maincolumn 'assets/loon/figure8.png' '' %}

The paper also visualizes the time to enactment for intents using different routes. In particular, it is clear that relying on satellite (SatCom) to enact intents is significant slower than relying on communication between the different nodes in the network.

{% maincolumn 'assets/loon/figure9.png' '' %}

## Conclusion

The paper on Loon's _TS-SDN_ approaches a well-trod idea (Software Defined Networks) from a new and unique angle. Along the way, the research also has more general takeaways.

First, the authors dig into their work on debugging why and how the system reached a specific state (a common problem area in distributed systems). Their focus on discerning "_correct_ system behavior versus _bugs_" is a helpful data point on what works for teams tackling similar problems in production. Relatedly, I enjoyed reading several concrete examples of trade-offs between explainability and computational power{% sidenote 'solver' "In particular about choosing a less-complex solver to make decisions about network structure, rather than a more complex (and less understandable) approach."%}.

I was also interested by the research's discussion of the disconnect between physical models and real-world conditions for balloons (and the users relying on them). For example, the solver structured the network based on potentially out-of-date weather data, meaning the system didn't accurately estimate the impact of moisture on the radio. In turn, this inaccurate calculation resulted in a suboptimal network structure, causing bad networking performance. As a result, the solver eventually evolved to rely on direct measurements of network performance, optimizing for improving the user experience (rather than relying on a more distant metric). Pivoting algorithms and decision-making to optimize user-focused metrics seems like a useful general takeaway!
