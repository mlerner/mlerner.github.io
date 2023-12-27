---
layout: post
title: "Blueprint: A Toolchain for Highly-Reconfigurable Microservice Applications"
categories:
---

## What is the research?

The Blueprint paper talks about a new framework for configuring, building, and depoloying microservices. This framework aims to simplify application development, as well as iterating on system design and configuration.

The authors argue that these tasks are currently difficult to accomplish because many services have tight coupling between application code, framework-level components (like RPC libraries and their behavior), and the actual deployment of the service (e.g. with Docker, Kubernetes, or other systems like Ansible).

By explicitly separating concerns of an application, and explicitly defining their interactions in a programmatic configuration, the authors are able to produce systems on which they can iterate faster - for example, being able to compare the performance of monoliths vs seperately deployed microservices.

## How does the system work?

Blueprint's approach divides a system into three types of components:

- Application level workflows: business logic that a developer writes to perform a specific function.
- Scaffolding: underlying framework-level components like RPC functionality, distributed tracing libraries, and storage backends (like caches and databases).
- Instantations: specific configuration for framework-level components (e.g. using a specific RPC library with deadlines set or with novel functionality like circuit-breakers enabled (TODO reference circuit-breakers)).

A system is described in a programmatic configuration called a _workflow spec_ that contains application logic and its external interface.

TODO fig1
TODO fig2

Next, a user of blueprint creates a _wiring spec_ that encode the relationship between pieces of application code and framework-level components. In one example, the authors recreate a simple microservice for posting on a social network, including connection to external caches and databases.

TODO fig3

Blueprint then uses the _wiring spec_ to create an _intermediate representation_ (TODO note that the idea of IR is common to compiled systems) of the system. The intermediate representation is effectively a graph with nodes describing code and edges describing dependencies (e.g. service A calls service B).

TODO figure 4

The intermediate representation is then turned into concrete artifacts representing the components of the system - for example, if a service written in Go relies on a gRPC library, and the application should be wrapped with a Doccker image, the a build system will compile the Go code and create a correponding Docker image that can later be pushed to production.

## How is the research evaluated?

The authors evaluate the six main research claims about the implementation:

- Does Blueprint make it easier for developers to try new configurations of an system's _existing_ components and libraries?
- Can Blueprint be used to create system configurations that reproduce reliability issues?
- Does Blueprint make it easier to adopt system-wide improvements?
- How closely do the systems that Blueprint generates reproduce existing reference systems?
- What is the difficulty of extending Blueprint's implementation?
- What are the costs of the abstractions that Blueprint provides?

## Conclusion