---
layout: post
title: "Defcon: Preventing Overload with Graceful Feature Degradation"
categories:
---

[Defcon: Preventing Overload with Graceful Feature Degradation](https://www.usenix.org/conference/osdi23/presentation/meza)

_This is one in a series of papers I'm reading from OSDI and Usenix ATC. These paper reviews can be [delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions!_

## What is the research?

Severe outages can occur due to system overload{% sidenote 'load' "Discussion of managing load [from the SRE book here](https://sre.google/workbook/managing-load/)."%}, impacting users who rely on a product, and potentially damaging underlying hardware{% sidenote 'failslow' "Damage to hardware can show up as _fail-slow_ situations, where performance degrades overtime. This is also discussed in a previous paper review on [Perseus: A Fail-Slow Detection Framework for Cloud Storage Systems](https://www.micahlerner.com/2023/04/16/perseus-a-fail-slow-detection-framework-for-cloud-storage-systems.html)"%}. It can also be difficult to recover from outages involving overloaded system due to additional problems this type of outages cause - in particular, [cascading failures](https://sre.google/sre-book/addressing-cascading-failures/). There are many potential root-causes to a system entering an overloaded state, including seasonal traffic spikes, performance regressions consuming excess capacity{%sidenote 'metastable' "This situation can lead to metastable failures, as discussed in a previous [paper review](https://www.micahlerner.com/2022/07/11/metastable-failures-in-the-wild.html)." %}, or subtle software bugs. As such, limiting the damage caused by overload conditions is a complicated problem.

To prevent overload from impacting its products, Meta developed a system called _Defcon_. Defcon provides a set of abstractions that allows incident responders to increase available capacity by turning off features, an idea called _graceful feature degradation_. By dividing product features into different levels of business criticality, Defcon also allows oncallers to take a variety actions depending on the severity of an ongoing incident.

{% maincolumn 'assets/defcon/figure1.png' '' %}

{% maincolumn 'assets/defcon/figure2.png' '' %}

The Defcon paper describes Meta's design, implementation, and experience deploying this system at scale across many products (including Facebook, Messenger, Instagram, and Whatsapp) along with lessons from usage during production incidents.

## Background and Motivation

The authors of Defcon describe several alternatives they considered when deciding how to mitigate the risk of system overload. Each of the options is evaluated on the amount of additional resources that the approach would consume during an incident, the amount of engineering effort required to implement, and the potential impact to users.

{% maincolumn 'assets/defcon/table1.png' '' %}

Given that serious overload events happen on a recurring basis (at least once a year), the authors decided to invest engineering resources in an engineering-intensive effort capable of limiting user impact.

## How does the system work?

The core abstraction in Defcon is the _knob_, which represents for each feature: a unique name, whether a feature is turned on or not, the oncall rotation responsible, and a "level" corresponding to business-criticality.

{% maincolumn 'assets/defcon/listing1.png' '' %}
{% maincolumn 'assets/defcon/features.png' '' %}

After a feature is defined using this configuration, servers or applications (for example, in Web or iOS devices) import the knob into code and implement code paths that handle cases when the _knob_ is turned off - for example, short-circuiting expensive logic.

{% maincolumn 'assets/defcon/listing2.png' '' %}

During testing and incident response, operators change a _knob_'s state via a command-line or user interface, and Defcon handles replicating this state to impacted consumers (like servers and mobile applications). Knob state is also stored in a database.

{% maincolumn 'assets/defcon/figure3.png' '' %}

Defcon's _Knob Actuator Service_ propagates state changes for two types of knobs: _server-side knobs_ and _client-side knobs_:

> _Server-side knobs_ are implemented in binaries running on the servers in data centers. The advantage of server-side knobs is that we can adjust the knobs’ state in seconds without any propagation delays.

> _Client-side knobs_ are implemented in client code running on phones, tablets, wearables, and so on. The advantage of client-side knobs is that they have the capability to reduce network load by stopping requests sent to the server along side reducing server load due to the request.

Client-side knobs (like those in an iOS application) are slightly more complex to update. Under normal conditions, they change via a push (called _Silent Push Notification (SPN)_) or routine pull (_Mobile Configuration Pull_) mechanism. To handle extenuating circumstances (like lower latency response to severe outages), Defcon can also instruct clients to pull a broader set of configuration stored in a specific server-location using a process called _Emergency Mobile Configuration_{% sidenote 'serious' "Under normal operating conditions, a full reset isn't used because it has the tradeoff of using more resources (in particular networking), which is unfriendly to user mobile plans and device batteries."%}.

Knobs are, "grouped into three categories: (1) By service name, (2) by product name, and (3) by feature name (such as “search,” “video,” “feed,” and so on)" to simplify testing during development and post-release. Testing occurs through small scale A/B tests (where one "experiment arm" of users experience feature degradation, and the "control" arm does not) and during larger exercises that ensure the Defcon system is working (described later in the paper). These tests also have the side effect of generating data on what capacity a feature or product is using, which serves as an input to capacity planning.

During incidents, oncallers can also use the output of these tests to understand what the potential implications are of turning off different knobs. The

{% maincolumn 'assets/defcon/figure4.png' '' %}

## How is the research evaluated?

The paper uses three main types of datasets to quantify Defcon's changes:

- _Real-time Monitoring System (RMS)_ and _Resource Utilization Metric (RUM)_, which aim to measure utilization of Meta infrastructure. The specifics of which one to use depends on the experiment, as discussed below.
- _Transitive Resource Utilization (TRU)_, which aims to measure the downstream utilization that a service has of shared Meta systems (like its graph infrastructure described in my previous paper review on [TAO: Facebook’s Distributed Data Store for the Social Graph](https://www.micahlerner.com/2021/10/13/tao-facebooks-distributed-data-store-for-the-social-graph.html)).
- _User Behavior Measurement (UBM)_, which tracks how changing a knob's state impacts business metrics like "Video Watch Time".

The first evaluation of Defcon's impact is at the Product-level. By turning off progressively more business-critical functionality, the system makes greater impact on Meta's resource usage{% sidenote 'mips' "Represented with _mega-instructions per second (MIPS)_, a normalized resource representation corresponding to compute." %}. Entirely turning off critical features (aka "Defcon Level 1"), saves a large amount of capacity, but also significantly impacts critical business metrics.

{% maincolumn 'assets/defcon/figure8.png' '' %}
{% maincolumn 'assets/defcon/table2.png' '' %}

Defcon is next evaluated for its ability to temporarily decrease capacity required of shared infrastructure. As discussed in a previous paper review of [Scaling Memcache at Facebook](https://www.micahlerner.com/2021/05/31/scaling-memcache-at-facebook.html), Meta uses Memcache extensively. By turning off optional features, oncallers are able to decrease load on this type of core system.

{% maincolumn 'assets/defcon/figure9.png' '' %}

Next, the research describes how Meta can decrease capacity requirements by turning off knobs in upstream systems with dependencies on other Meta products. For example, turning off Instagram-level knobs decreases load on Facebook, which ultimately depends on TAO, Meta's graph service. Testing knobs outside of incident response surfaces resource requirements from these interdependencies.

{% maincolumn 'assets/defcon/figure12.png' '' %}

The Defcon paper describes a protocol for forcing Meta systems into overload conditions, and testing the impact of turning progressively more business-critical features off. By ramping user traffic to a datacenter, these experiments place increasing load on infrastructure - turning knobs off then alleviates load.

{% maincolumn 'assets/defcon/figure15.png' '' %}

## Conclusion

The Defcon paper describes a framework deployed at scale in Meta for disabling features in order to mitigate overload conditions. To reach this state,  the authors needed to solve technical challenges of building the system and to collaborate with product teams to define feature criticality - in some ways, the latter seems even more difficult. The paper also mentions issues with maintainability of knobs. On this front, it seems like future work could automate the process of ensuring that knobs cover features inside of deployed code. Lastly, I'm looking forward to learning more about Defon's integration with other recently published Meta research, like [the company's capacity management system](https://www.usenix.org/conference/osdi23/presentation/eriksen).