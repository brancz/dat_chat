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

	docker-compose up -d

The individual containers, especially the web containers, take a while to
startup. Take a look at the HAProxy container to see when things are up and
running. It should tell you that all three web endpoints are reachable.
Something like this:

```
haproxy_1 | [WARNING] 101/193753 (1) : Server frontend/web1 is UP, reason: Layer4 check passed, check duration: 0ms. 1 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
haproxy_1 | [WARNING] 101/193755 (1) : Server frontend/web0 is UP, reason: Layer4 check passed, check duration: 0ms. 2 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
haproxy_1 | [WARNING] 101/193756 (1) : Server frontend/web2 is UP, reason: Layer4 check passed, check duration: 0ms. 3 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
```

Now we can start having fun. To try out the highly available redis + websocket,
first visit the web-frontent at `http://docker-ip:8081`. (usually `docker-ip`
is `localhost` or your `boot2docker ip`, depending on how you are using docker)
Then sign up and sign in. Next locate the webserver that build the websocket
connection with the webbrowser. You'll have to check the logs of `web0`, `web1`
and `web2`.

	docker-compose logs

The line we are searching for looks something like this (the important part is
the `"GET / HTTP/1.1" HIJACKED`

```
web1_1          | 172.17.0.34 - - [12/Apr/2015 19:38:09] "GET / HTTP/1.1" HIJACKED -1 0.4130
```

In this case it is `web1`. Keep an eye on that container's logs, and those of
the `redissentinel` container.

	docker-compose logs web1 redissentinel

Then stop the `redismaster` container

	docker-compose stop redismaster

Now we can watch redis-sentinel promote the redis-slave to a master. And the
web container trying to reconnect the Pub/Sub to the new redis master.

```
redissentinel_1 | 1:X 12 Apr 19:39:42.656 # +sdown master mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:42.656 # +odown master mymaster 172.17.0.22 6379 #quorum 1/1
redissentinel_1 | 1:X 12 Apr 19:39:42.656 # +new-epoch 1
redissentinel_1 | 1:X 12 Apr 19:39:42.657 # +try-failover master mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:42.660 # +vote-for-leader 21800d3bab152b09d2ed0a3a632ee0dcc11db6f5 1
redissentinel_1 | 1:X 12 Apr 19:39:42.661 # +elected-leader master mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:42.661 # +failover-state-select-slave master mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:42.727 # +selected-slave slave 172.17.0.24:6379 172.17.0.24 6379 @ mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:42.727 * +failover-state-send-slaveof-noone slave 172.17.0.24:6379 172.17.0.24 6379 @ mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:42.790 * +failover-state-wait-promotion slave 172.17.0.24:6379 172.17.0.24 6379 @ mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:43.675 # +promoted-slave slave 172.17.0.24:6379 172.17.0.24 6379 @ mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:43.675 # +failover-state-reconf-slaves master mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:43.743 # +failover-end master mymaster 172.17.0.22 6379
redissentinel_1 | 1:X 12 Apr 19:39:43.743 # +switch-master mymaster 172.17.0.22 6379 172.17.0.24 6379
redissentinel_1 | 1:X 12 Apr 19:39:43.743 * +slave slave 172.17.0.22:6379 172.17.0.22 6379 @ mymaster 172.17.0.24 6379
redissentinel_1 | 1:X 12 Apr 19:39:48.794 # +sdown slave 172.17.0.22:6379 172.17.0.22 6379 @ mymaster 172.17.0.24 6379
web1_1          | reconnecting to new redis master
web1_1          | reconnecting to new redis master
web1_1          | reconnecting to new redis master
```

## How it works & outlook

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
