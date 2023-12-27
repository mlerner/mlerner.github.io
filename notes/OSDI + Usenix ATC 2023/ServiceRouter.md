- Link to the paper
- Outline
    - What is the research and why does it matter?
    - How does it work?
    - How is the research evaluated?
    - Conclusion
- Overview
    - [[The Five C's]]
        - [ ]  **Category**: What type of paper is this? A measurement paper? An analysis of an existing system? A description of a research prototype?
        - [ ] **Context**: Which other papers is it related to? Which theoretical bases were used to analyze the problem?
        - [ ] **Correctness**: Do the assumptions appear to be valid?
        - [ ] **Contributions**: What are the paper’s main contributions?
	        - [ ] Hyperscale
	        - [ ] Support a diversity of router types
	        - [ ] Sharded services support
	        - [ ] Locality aware routing
        - [ ] **Clarity**: Is the paper well written?
    - Notes
	    - Introduction
		    - Differences between ServiceRouter and other proxies.
			    - ServiceRouter is embedded inside the application, which has some cons potentially
			    - Hyperscale (true of other approaches as well)
			    - Sharded services (ShardManager)
			    - Locality Rings
			- Features of ServiceRouter
				- service discovery, load balancing, failover, authentication, encryption, observability [1], overload protection [39], distributed request tracing [32], resource attribution for capacity management [16], and duplication of traffic for shadow testing.
			- SDN approach isn't ideal,better to have distributed approach for routing
				- They compare sidecar-based approach to ServiceRouter
					- TODO figure 1 
					- TODO figure 2
			- There are a few components of ServiceRouter
				- Routing Information Base
				- Data Distribution Layer (RIB replicas)
				- Dedicated balancer
				- Sidecar proxys
				- Library
			- Hardware cost
				- Compared to Istio, which consumes 0.35 vCPU per
					- 160965000
				- Pros and cons of linking the library into executable
					- Including that some languages don't have support 
		- Comparison of Services Mesh Architectures
			- TODO figure 4, which shows all different types of routers
			- SRLib
				- There are actually two components, one of which has very spike CPU usage so it makes sense to separate
			- SRLookaside
				- They don't even use this anymore because they had the solution for power consumption reasons
			- SRSidecarProxy
				- Similar to Istio, but better!
				- Mostly used for Erlang (does Meta still use Erlang for Whatsapp? https://news.ycombinator.com/item?id=21111662)
			- SRRemoteProxy
				- They have different ways of running the routers
			- SRProxy is better in some situations (like cross region)
				- TODO figure 5
		- ServiceRouter Design
			- Overview
				- Routing Information Base
					- Uses Paxos
				- Global Registry Service (Service and shard discovery)
					- TODO figure 7, shards are part of this
				- Configuration Management System
					- Customize the routing policy via code that is committed
				- LMS (automation around minimizing cross-region latency)
					- "latency monitoring service (LMS) periodically aggregates and commits configuration updates related to cross-region latency to guide"
				- xRS (cross region routing) - this helps with making optimal decisions for cross-region routing
			- Service Discovery
				- miniRIB - local cache
				- RIBDaemon - takes to store the RIB like persisting it to disk
				- in the happy case, the cluster manager will remove entries for a service before shutting it down. In bad situations, the cluster manager still handles the problem.
			- Support for sharded services
				- Clients ask for keys and primary/secondary of a service and SR figures it out
				- TODO what do applications do for sharded services with Istio or similar solutions?
				- There are other approaches for sharding, but they don't really experience use at Meta (consistent hashing, lookaside which is supported by gRPC)
			- Load balancing
				- They have pick-2, but they also have other approaches
					- Consider regional locality when sampling two random servers (§3.4.1). 
						- Look for two servers that are in the closest ring
						- Cross region routing table
					- Sample two random servers from a stable subset of servers, rather than all servers, to maximize connection reuse (§3.4.2). 
						- With SR, each RPC client uses Rendezvous Hashing to select a stable servers, which achieves the ideal properties described above.
							- They talk about using rendezvous hashing over consistent hashing
					- Take an adaptive approach to load estimation based on the workload characteristics (§3.4.3).
		- Evaluation
			- Does SR scale well? (§ 4.1) 
				- Many services use few servers, some use alot
				- wide distribution in RPS
				- RIB could become a bottleneck
				- Routing configuration changes are broken down by a few things
					- "To understand the nature of routing-configuration changes, we list the types of the most frequent changes on an average day. A data pair (X%/Y) below means that every day X% of the total changes are for a specific type, which are applied to Y number of services. The top types of changes are 1) processing timeout (27%/1700), the server-side RPC processing timeout; 2) locality ring (30%/700); 3) traffic shedding (11%/3), the percentage of traffic to be shed for a given client ID in an overload situation; and 4) shadow traffic (6%/100), the percentage of production traffic to be replicated to a test service."
			- To what extent does SRLib save hardware costs, and when should one use SRProxy versus SRLib? (§ 4.2)
				- SRLib (embedded)
				- SRProxy (like istio)
				- Thrift (basic RPC mechanism)
					- https://thrift.apache.org/
				- Basically RPC latency approx similar for Thrift and SRLib, and SRProxy is a lot worse relatively
					- TODO Figure 10
				- "If we were to completely switch from SRLib to SRProxy and route 100% of the RPC traffic by SRProxy, we would need hundreds of thousands of additional machines for SRProxy."
				- There are some case studies where they are able to say, tradeoff this latency for this amount of cost
				- Connection reuse is big with SR Proxy
			- Can SR balance load within and across regions? (§ 4.3)
				- Same-region
					- Very similar load for unsharded services
					- Sharded services, the load can differ significantly but it is mostly due to differences in traffic to shards
				- Cross-region load balancing
					- Most services use the default locality ring, but there are different configurations of locality rings
					- During a spillover event, traffic shifted to different rings of the services. Little impact to users from spillover
			- Are sharded services important, and can SR effectively support both sharded and unsharded services? (§ 4.4)
				- How much traffic actually go to sharded services? alot.
				- What is the overhead of sharded services?
					- Actually, the sharding updates change how traffic is routed fairly frequently
		- Limitations
			- Dynamic policy updates
				- We know that compiling things into applications isn't the best, but there are Meta solutions for solving configuration propagation
			- You have to modify the callsites to use the library
			- Library code development: how do you safely make changes to the library at scale?
			- Bugs in SRLib: they have ways of gating features, but that also seems dangerous
		- Related work
		- Conclusion
- Questions
    - [[What is the motivation for the paper?]]
    - [[What are the paper's contributions?]]
    - [[How does the paper relate to existing solutions?]]
    - [[How does the paper evaluate it's solution?]]
- Worklog
- Checklist
    - [ ] First pass <15 minutes>
        - [x] Carefully read the title, abstract, and introduction
        - [ ] Read the section and sub-section headings, but ignore everything else
        - [ ]  Read the conclusions
        - [ ] Glance over the references, mentally ticking off the ones you’ve already read
        - [ ] Answer [[The Five C's]]
    - [ ] Second pass <60 minutes>
        - Read the paper with greater care, but ignore details such as proofs
            - [ ]  Look carefully at the figures, diagrams and other illustrations in the paper. Pay special attention to graphs. Are the axes properly labeled? Are results shown with error bars, so that conclusions are statistically significant? Common mistakes like these will separate rushed, shoddy work from the truly excellent
            - [ ] Remember to mark relevant unread references for further reading (this is a good way to learn more about the background of the paper).
    -  [ ] Third pass - 4 hours <optional>