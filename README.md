# Dat Chat

JRuby + Redis + Websockets = Distributed Chat

This project is intended to be an example application to use when demonstrating
a distributed system.

Before you ask WHY?! Because I can! And I use it as an example application when
trying out the latest clustering setups/tools.
([Kubernetes](http://kubernetes.io/), [Mesosphere](http://mesosphere.com/),
[Docker Swarm](http://docs.docker.com/swarm/), etc.)

## Usage

To try out this application you will need to have
[Docker](https://docs.docker.com/installation/) and [Docker
Compose](https://docs.docker.com/compose/) installed.

First you have to pull and build the used images

	docker-compose build

Then you can already start the application

	docker-compose up

Or to start the containers as daemons

	docker-compose start

## Explanation

So what are we doing here? The application itself is a webserver written in
[JRuby](http://jruby.org/) using [sinatra](http://www.sinatrarb.com/) as the
web-framework and
[faye-websockets](https://github.com/faye/faye-websocket-ruby) for websocket
handling.

Since it is a distributed chat there will be several webservers and websockets,
which have to be able to communicate with each other, even if the users landed
on different webservers by luck. To handle this problem
[redis](http://redis.io/) is used with its
[Pub/Sub](http://redis.io/topics/pubsub) features. And since redis is already
present, it is also used as a storage mechanism for the messaging history. I
realize that in real live production environments this would probably be done
differently, since there is a chance that redis has not persistet the history
completely in case of a crash. Redis has a pretty easy [high availability
setup](http://redis.io/topics/cluster-tutorial) using redis-sentinel.

Since we have now decoupled the websockets from the webserver, we can easily
add more instances of the webserver. To load balance access to those webservers
we are using HAProxy. Here's a picture of what that architecture would look
like.

![current architecture](https://raw.githubusercontent.com/flower-pot/dat_chat/master/docs/current-architecture.png)

When you look at my current HAProxy configuration you will notice that it is
very simple. It is just meant for locally trying out the application. It is
not suited for production use.

To allow clustering of the HAProxy we would need something like an [Elastic IP
Address](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html).
Then we could use [keepalived](http://www.keepalived.org/) to notice when a
HAProxy is not available and route the client to a working instance. Then the
architecture's picture would look like this, as described
[here](https://blog.logentries.com/2014/12/keepalived-and-haproxy-in-aws-an-exploratory-guide/).

![desired architecture](https://raw.githubusercontent.com/flower-pot/dat_chat/master/docs/desired-architecture.png)
