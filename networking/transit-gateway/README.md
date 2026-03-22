# Transit gateway

https://catalog.workshops.aws/networking/en-US/foundational/multivpc/tgw-routing

# one-to-one
- create tgw
- create tgw attachment for every VPC to be peered
    - place attachment to own small subnet
    - disable automation assocation and propagation
- create tgw route table
    - associate attachments to route traffic va tgw
    - propagate attachments to have learnt routes added to the route table
- add route to every workload route table for IP range available via tgw

# Hub-and-spoke
- tgw and tgw attachments created
- create tgw route tables - shared and spoke
- shared RT
    - associate vpc-a (hub)
    - propagate vpc-b and vpc-c to have routes created for traffic from vpc-a
- spoke RT
    - associate vpc-b and c
    - propagate vpc-a to have the route created for traffic from vpc-b a c
- workload vpcs have routes to tgw gateway for each peered VPC
- now vpc-b and c can reach only vpc-a
