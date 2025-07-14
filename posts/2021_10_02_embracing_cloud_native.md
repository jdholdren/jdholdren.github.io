*This post was created from my time at Big Nerd Ranch, but they've since disbanded.
I've moved the content here so it's still available.*

Cloud infrastructure has pushed software towards abstracting the developer away from the operating hardware, making global networks and copious amounts of computing power available over API's, and managing large swaths of lower tiers of the tech stack with autonomous software. Gone are the days of buying bulky servers to own and here are the times of renting pieces of a data center to host applications. But how does designing for a cloud environment change your application? How do software teams take advantage of all the advancements coming with this new set of infrastructure? This article will go over three pillars of a "Cloud-Native" application and how you can embrace them in your own software.

## Embracing Failure

One incredible paradigm the Cloud has brought forth is represented in the Pets vs Cattle analogy. It differentiates how we treat our application servers between _pets_, things that we love and care for and never want to have die or be replaced, and _cattle_, things that are numbered and if one leaves another can take its place. It may sound cold and disconnected, but it embraces the failure and accepts it using the same methodology of "turning it off and on again". This aligns with the Cloud mentality of adding more virtual machines and disposing of them at will, rather than the old ways of keeping a number of limited, in-house servers running because you didn't have a whole data center available to you.

To utilize this methodology, it must be easy for your app to be restarted. One way to reflect this in your app is to make your server _stateless_, meaning it doesn't persist state on its own disk: it delegates state to a database or a managed service for handling state in a resilient way. For connections or stateful attachments to dependencies, don't fight it and try to reconnect when something goes down: just restart the application and let the initialization logic connect again. In cases where this isn't possible, the orchestration software will kill the application, thinking it's unhealthy (which it is) and try to restart it again, giving you a faux-exponential-backoff loop.

The above thinks of failure as binary: either the application is working or it isn't, and let the orchestration software handle the unhealthy parts. But there's another method to compliment these failure states, and that's handling degraded functionality. In this scenario, _some_ of your servers are unhealthy, but not all of them. If you're already using an orchestration layer, you'll likely already have something to handle this scenario: the software managing your application sees that certain instances are down, so it reroutes traffic to healthy instances and will return traffic when the instances are healthy again. But in the scenario where entire chunks of functionality are down, you can handle this state and plan for it. For example, you can return data _and_ errors in a graphql response:

```json
{
  "data": {
    "user": {
      "name": "James",
      "favoriteFood": "omelettes",
    },
    "comments": null,
  },
  "errors": [
    {
      "path": [
        "comments"
      ],
      "locations": [
        {
          "line": 2,
          "column": 3
        }
      ],
      "message": "Could not fetch comments for user"
    }
  ]
}
```

Here parts of the application were able to return user data, but comments weren't available, so we return what we have, accepting that failure and working with it rather than returning no data. Just because _parts_ of your application aren't healthy doesn't mean the user can't still get things done with the _other parts_.

## Embracing Agility

A more agile application means it's quicker to start and schedule should you need more instances of it. In scenarios where the system has determined it needs more clones of your app, you don't want to wait 5 or more minutes for it to get going. After all, in the Cloud we're no longer buying physical servers: we're renting the space and computing power that we need, so waiting for applications to reach a healthy state is wasting money. For your users, bulky, "slow-to-schedule" applications mean a delay in getting more resources and degraded performance or, in worse scenarios, an outage because servers are overloaded while they wait on reinforcements.

Whether you're coming from an existing application or looking to make a Cloud-Native one from the start, the best way to make an application more agile is to think smaller. This means that the server you're constructing is doing less, reducing start time and becoming less bloated with features. If your application is large and has unwieldy dependencies on prerequisite software installed on the server, consider removing those dependencies by delegating them to a third party or making it into a service to be started elsewhere. If your application is still too large, consider microservices, where appropriately sized and cohesive pieces of the total application are deployed separately and communicate over a network. It can increase complexity in operating the total application, but microservices can also lessen the cognitive load required to manage any individual piece with it or also coupled to the rest of the whole.

## Embracing Elasticity

Following the points from above, if it's easier to run instances of your application, it's easier for the software to autonomously manage _how many_ are running. This means the infrastructure managing your app can monitor the traffic or resource usage and start to add more instances to handle the increased load. In times where there's less usage, it can scale down your resources to match. This is a huge departure from how elasticity was thought of using a traditional model: previously, you bought servers and maintained them, so you didn't plan for just adding them on the fly. To compensate for dynamic amounts of load, you had to take the topmost estimate and add buffer room for extra heavy traffic times. During normal operation, there was capacity just sitting around unused. And to increase capacity, you likely tried to add more capacity to a single machine with upgrades and newer internals.

Again, to benefit from the elasticity that the Cloud gives you, it's best to make it easier to enjoy that benefit. You can follow the tips on agility to make your application smaller, but before that, it might important to make it possible to run many instances of your application in the first place. This can mean removing any logic that counts on a fixed number of instances running, like using a single instance of a server because you need locks to handle concurrent logic. For scenarios like that, you can use locks provided by your database or your caching solution. All in all, the idea should be to look at logical factors that prevent you from running a _second_ or _third_ instance of your application in parallel. Ask yourself what are the downsides or complications of just adding _one more_ instance of your app, and create a list of barriers. Once you've removed those, you'll find that running tens or hundreds of instances in parallel is now possible.

## Conclusion

The Cloud has changed the way we think about and run software, and your existing application may need to change to best utilize it. With so much of the infrastructure managed with autonomous software, new tooling has made it easier than ever to manage entire fleets of applications, removing the developer further away from the gritty details. It has pushed software deployments to be more agile, embrace failure as normal, and allow scaling by adding instances instead of making faster machines. If you're not already running with all the Cloud has to offer, give it another look and see if it aligns with your future needs, both for your business and your application.
