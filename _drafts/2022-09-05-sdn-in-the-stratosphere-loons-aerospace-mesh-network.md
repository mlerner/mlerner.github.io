---
layout: post
title: "SDN in the Stratosphere: Loon’s Aerospace Mesh Network"
categories:
---

[SDN in the Stratosphere: Loon’s Aerospace Mesh Network](TODO)

## What is the research?

Loon was a project to provide internet connectivity via a network of balloons in low-earth orbit{% sidenote 'leo' "TODO talk about what LEO is"%}. Founded in 2011, the project successfully created mesh networks{% sidenote 'mesh' "TODO describe mesh networks" %} covering thousands of kilometers, using devices deployed into harsh conditions for up to three hundred days at a time.

While the project shut down in TODO, the authors open-sourced important artifacts from development{% sidenote 'artifacts' "TODO cite artifacts"%}. This paper covers one of the system's critical components responsible for configuring the network served by the balloons. This component, called the _Software Defined Network (SDN)_, was able to change network structure in response to challenges like weather conditions, balloon drift, and interference from geological features.

Since Loon's initial development, the cost of deploying satellites dropped dramatically{% sidenote 'cost' "TODO cite https://www.nbcnews.com/science/space/space-launch-costs-growing-business-industry-rcna23488"%}. As a result, a balloon-based approach may no longer provide the same benefits it did at the project's inception. Nevertheless, the learning from the project will be useful to other projects with moving platforms, like those from SpaceX!

## What are the paper's contributions?

The paper makes three main contributions:

- Documentation of the challenges and tradeoffs that went into the design of the SDN.
- A description of the system's architecture.
- Performance metrics and evaluation using metrics from Loon's production deployment.

## How does the system work?

The main goal of a _Software Defined Network (SDN)_ is to program devices on a network so that they can successfully provide network connectivity.

While attempting to solve this goal, the Loon SDN faced several challenges:

- Navigation:
- Power:
- Radio links:
- Command & Control:

To tackle these challenges, the project developed an approach based on separated control and data planes{% sidenote 'separate' "TODO explain control plane / data plane"%}.

TODO figure 3

The system had five main components{% sidenote 'six' "TODO there was also the mobile network operator that provides the actual internet services"%}:

- Balloons: the actual components of the mesh network
- Satellites: used to bootstrap the network, and had limited bandwidth.
- Remote data centers: satellites connnected to these remote data centers while bootstrapping the network
- Edge compute: owned data centers that acted as a central hub
- Ground stations: remotely deployed infrastructured that balloons connected to for the majority of their networking needs.

Control planes are often responsible for configuring networking equipment. The control plane of the SDN performed this function by relying on satellite links for bootstrapping balloons onto the network. After bootstrapping, the SDN programs a balloon's networking device to connect to nearby ground stations or other already-bootstrapped balloons. After this initial setup, control-plane configuration flowed through the network via _Ad hoc On-Demand Distance Vector Routing (AODV)_, an approach to routing in mesh networks{% sidenote 'manet' "TODO cite https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5076215"%}.

The control plane messages configure connectivity and packet routing in the data plane. To achieve network performance, the SDN needed to respond to consume data on changing conditions and use that data to reconfigure the network. In particular, it consumed three main types of inputs when making decisions: _physical model_, _logical model_, _network management information_.

The physical model represented information like:

- Motion and orientation
- Weather conditions:
- Platform definitions:
- Interference constraints

The _network model_ primarily stored TODO

Lastly, actions taken by Loon engineers could influence the state of the network. For example TODO

- Admin actions
- Connectivity requests

### SDN Decision-making

The SDN ingested the above datasources in order to configure the future state of the network. First, the SDN used elements of the physical model to identify _candidate links_ - in other words, connectivity between different components of the network that could exist. Next, it combined these candidates with the current state of the network (represented as the _network model_), and network administrative actions to produce a set of _intents_ representing the state that the network should converge to in the future{% sidenote "intent" "TODO consider writing about intent-based / OpenFlow here"%}. The SDN then _actuated_ intents, programming ground stations and balloons so that they formed they right networking connections.

TODO figure 5

Actually executing the SDN commands was a difficult problem in and of itself. TODO cite control plane composition

### Explainability

TODO

## Conclusion

While the Loon project is no longer running, the published artifacts associated with its design and implementaiton may serve as a helpful reference to those building non-terrestrial networks in the future. I found the description of the variety of unique challenges faced by the team illimunating. I hope to contrast the system's design with other SDNs in a future paper review!
