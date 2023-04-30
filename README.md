<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Getting Stated with Apache Kafka](#getting-stated-with-apache-kafka)
  - [Installation](#installation)
  - [Architecture](#architecture)
    - [Messaging System](#messaging-system)
    - [Kafka Cluster](#kafka-cluster)
    - [Distributed Consensus with Zookeeper](#distributed-consensus-with-zookeeper)
  - [Understanding Topics, Partitions, and Brokers](#understanding-topics-partitions-and-brokers)
    - [Topics in Detail](#topics-in-detail)
    - [Consumer Offset and Message Retention Policy](#consumer-offset-and-message-retention-policy)
    - [Demo](#demo)
    - [Distributed Commit Log](#distributed-commit-log)
    - [Partitions in Detail](#partitions-in-detail)
    - [Distributed Partition Management](#distributed-partition-management)
    - [Achieving Reliability](#achieving-reliability)
    - [Demo Fault-tolerance and Resiliency](#demo-fault-tolerance-and-resiliency)
  - [Producing Messages with Producers](#producing-messages-with-producers)
    - [Intro](#intro)
  - [Consuming Messages with Consumers](#consuming-messages-with-consumers)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Getting Stated with Apache Kafka

Notes from Pluralsight [course](https://app.pluralsight.com/library/courses/apache-kafka-getting-started/table-of-contents).

## Installation

Rather than installing Kafka directly on your machine, use [docker-compose.yml](https://github.com/karafka/karafka/blob/master/docker-compose.yml) from [Karafka](https://github.com/karafka/karafka).

Start Kafka & Zookeeper with docker:

```
docker-compose up
```

In another terminal run shell in kafka container:

```
docker-compose exec kafka bash
```

In the shell, you can run any Kafka commands, eg:

```bash
./opt/kafka/bin/kafka-topics.sh --create --topic my_topic --replication-factor 1 --partitions 1 --zookeeper zookeeper:2181
```

May need to `docker rm -f zookeeper_learning` and `docker rm -f kafka_learning` or figure out how to clean `/tmp` dirs between start/stop.

## Architecture

### Messaging System

![pub sub](doc-images/pub-sub.png "pub sub")

- pub/sub messaging system
- publisher (aka producer) creates message and sends to particular location
- interested and authorized subscriber (aka consumer) can retrieve these messages
- producers and consumers are applications that a developer writes that implement producing and consuming APIs
- messages are produced to (or consumed from) a *topic*
- topic is a grouping/collection of messages
- topics have a specific name
- producers produce a message to a named topic
- consumers retrieve messages from a named topic

![pub sub](doc-images/pub-sub-broker.png "pub sub")

- Messages and topics are maintained in a *broker*.
- Broker is a software process (daemon) that runs on a physical or virtual machine
- Broker has access to file system on the machine, which is where the messages are stored.
- Broker categorizes messages as topics.
- Multiple brokers can run on a machine but each must have unique settings to avoid conflicts

### Kafka Cluster

![cluster](doc-images/cluster.png "cluster")

* High-throughput distributed messaging system.
* Ability to process in parallel on multiple nodes.
* To achieve high throughput with Kafka, scale out the number of brokers
* Increasing number of brokers has no effect on existing producers and consumers
* A cluster is a *grouping* of multiple Kafka brokers
* Can have a single broker or multiple brokers on a single machine, or brokers on different machines.

**Cluster Size**

![cluster size](doc-images/cluster-size.png "cluster size")

Examples:
* A single broker on a single machine -> cluster size is 1
* Two brokers running on same machine -> cluster size is 2
* Two brokers each running on their own machine -> cluster size is still 2

**Zookeeper**

* Independent brokers must be grouped together to form a cluster
* Grouping mechanism that determines a clusters membership of brokers is key to Kafka's architecture - this is what enables it to scale, and be distributed and fault-tolerant.
* Zookeeper is what manages this - more later in course.

### Distributed Consensus with Zookeeper

Used in many distributed systems such as Hadoop, HBase, Mesos, Solr, Redis, Neo4j. Complex enough to have its own course, only touching on it here.

It's a centralized service for maintaining metadata about a cluster of distributed nodes, this metadata includes:

* Config info
* Health status
* Group membership (includes roles of elected nodes - who is the leader)

Zookeeper is also a distributed system, runs on multiple nodes that form an *ensemble*. Typically one ensemble powers one or many Kafka clusters.

**All Together Distributed Architecture**

![distributed arch](doc-images/distributed-arch.png "distributed arch")

Each component can scale out.

## Understanding Topics, Partitions, and Brokers

### Topics in Detail

* Main Kafka abstraction
* Named feed or category of messages
* Analogy to mailbox: addressable, referencable collection point for messages
* Producers produce a message to a topic
* Consumers consume messages from a topic
* Topic is a *logical entity*
* Topic spans across entire cluster of brokers
* Producers and consumers don't need to worry about where/how messages are stored, all they need is topic name
* Physically, each topic is maintained as one or more log files

**Logical View of Topic**

![topic logical](doc-images/topic-logical.png "topic logical")

![topic logical time](doc-images/topic-logical-time.png "topic logical time")

* When producer sends message to a topic, messages are appended to time-ordered sequential stream
* Each message represents an event (aka fact)
* Events are immutable - once received into topic, can't be modified
* If producer sends incorrect message, has to send more message(s) that are correct
* Consumer is responsible for reading the messages and reconciling them if a newer message "corrects" the mistake of an older message

**Event Sourcing**

Architectural style: Application state maintained by capturing all changes as a sequence of time-ordered, immutable events.

**Message Content**

![message content](doc-images/message-content.png "message content")

Each message has:
- timestamp when message is received by broker
- unique ID (combination of timestamp and ID form its placement in the sequence of messages contained in topic)
- consumers can reference the message ID
- message contains binary payload of data

**Many Consumers**

![many consumers](doc-images/many-consumers.png "many consumers")

* Message consumption can happen from any number of independent/autonomous consumers.
* If one consumer erroneously consumes a message, or crashes altogether, does not impact any other consumers.

### Consumer Offset and Message Retention Policy

* Message offset is how multiple consumers maintain their autonomy when consuming messages from the same topic.
* Offset is similar to a bookmark that maintains the last read position, it's the last read message.
* Offset is maintained by consumer
* Offset refers to message identifier

![consume from beginning](doc-images/consume-from-beginning.png "consume from beginning")

* When consumer wants to read from a topic, first it establishes connection with broker.
* Then consumer decides which messages it wants to consume
* Consumer can issue a statement to read `from beginning` of topic, this implies: `{ offset: 0 }`

![consume from last offset](doc-images/consume-from-last-offset.png "consume from last offset")

Another consumer can also read this topic, but has already consumed the existing messages, and is waiting for more messages to arrive. In this case it will read `from last offset`. Consumer uses offset to keep track of where it left off in the topic.

When new messages arrive, connected consumer(s) receive event indicating there's a new message, and the consumer can advance its position after retrieving the new message. When last message is read, consumer advances its offset, and its all caught up.

**Message Retention Policy**

* Slow consumers do not affect broker performance because Kafka can retain messages for a long time.
* This value is configurable - message retention policy.
* Messages are retained even after consumer(s) have consumed the messages.
* Default retention period is 168 hours (i.e. 7 days), after this, oldest messages will disappear.
* Retention period set on per-topic basis.
* Physical storage resources can constrain message retention.

### Demo

Start Kafka & Zookeeper with docker:

```
docker-compose up
```

In another terminal run shell in kafka container:

```
docker-compose exec kafka bash
```

In container, create topic:

```bash
./opt/kafka/bin/kafka-topics.sh --create --topic my_topic --replication-factor 1 --partitions 1 --zookeeper zookeeper:2181
```

Output:

```
WARNING: Due to limitations in metric names, topics with a period ('.') or underscore ('_') could collide. To avoid issues it is best to use either, but not both.
Created topic my_topic.
```

Zookeeper is responsible for assigning a broker to manage this topic.

Looking at Kafka logs when `my_topic` was created:

```
kafka_learning | [2023-04-29 18:32:05,155] INFO [ReplicaFetcherManager on broker 1001] Removed fetcher for partitions Set(my_topic-0) (kafka.server.ReplicaFetcherManager)
kafka_learning | [2023-04-29 18:32:05,161] INFO [Log partition=my_topic-0, dir=/kafka/kafka-logs-16da2ec9e4a4] Loading producer state till offset 0 with message format version 2 (kafka.log.Log)
kafka_learning | [2023-04-29 18:32:05,171] INFO Created log for partition my_topic-0 in /kafka/kafka-logs-16da2ec9e4a4/my_topic-0 with properties {} (kafka.log.LogManager)
kafka_learning | [2023-04-29 18:32:05,180] INFO [Partition my_topic-0 broker=1001] No checkpointed highwatermark is found for partition my_topic-0 (kafka.cluster.Partition)
kafka_learning | [2023-04-29 18:32:05,182] INFO [Partition my_topic-0 broker=1001] Log loaded for partition my_topic-0 with initial high watermark 0 (kafka.cluster.Partition)
```

Notice it created a log file in directory: `/kafka/kafka-logs-16da2ec9e4a4/my_topic-0`, looking at this on Kafka server, it shows an index and log file created for topic, will cover these more later.

```
$ ls -l /kafka/kafka-logs-16da2ec9e4a4/my_topic-0
total 4
-rw-r--r-- 1 root root 10485760 Apr 29 18:32 00000000000000000000.index
-rw-r--r-- 1 root root        0 Apr 29 18:32 00000000000000000000.log
-rw-r--r-- 1 root root 10485756 Apr 29 18:32 00000000000000000000.timeindex
-rw-r--r-- 1 root root        8 Apr 29 18:32 leader-epoch-checkpoint
```

Can also ask kafka to list the existing topics:

```
./opt/kafka/bin/kafka-topics.sh --list --zookeeper zookeeper:2181
benchmarks_00_01
benchmarks_00_05
benchmarks_00_10
benchmarks_01_05
my_topic
```

Instantiate a producer:

```
./opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic my_topic
```

Then keep the terminal open and start typing messages. Every time you hit <kbd>Enter</kbd>, the producer will send that text as a message to the broker, which will commit the message to the topic log, eg:

```
>MyMessage 1
>MyMessage 2
>MyMessage 3
>MyMessage 4
```

Now looking at the topic log file again, its grown from 0 to 316 bytes:

```
$ ls -l /kafka/kafka-logs-16da2ec9e4a4/my_topic-0
-rw-r--r-- 1 root root 10485760 Apr 29 18:32 00000000000000000000.index
-rw-r--r-- 1 root root      316 Apr 29 21:37 00000000000000000000.log
-rw-r--r-- 1 root root 10485756 Apr 29 18:32 00000000000000000000.timeindex
-rw-r--r-- 1 root root        8 Apr 29 18:32 leader-epoch-checkpoint
```

Contents of log file are binary but you can see the string messages:

```
cat /kafka/kafka-logs-16da2ec9e4a4/my_topic-0/00000000000000000000.log
C�)������|����|��������������"MyMessage 1CW������d����d��������������"MyMessage 2C�I�U����������������������"MyMessage 3CŕK�����������������������"MyMessage 4
```

Instantiate a consumer:

```
./opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic my_topic --from-beginning
```

It retrieves the messages and outputs them to console:

```
MyMessage 1
MyMessage 2
MyMessage 3
MyMessage 4
```

Go back to producer terminal and write more messages, will see the consumer terminal automatically update.

### Distributed Commit Log

Analogy to relational database commit log:

* Which is the ultimate source of truth about what happened.
* It continuously appends events in order in which they are received.
* Log files are physically stored/maintained.
* Higher-order data structures are derived from the log (eg: tables, indexes, views are just projections from authoritative source of truth which is the commit log)
* Commit log used for recovery in case of crash, data is restored from commit log. Reading from log -> reply all events in order in which they occurred.
* Commit log is also used for replication and distribution (redundancy, fault tolerance, scalability).

Kafka is a pub/sub messaging rethought as a *distributed commit log*. i.e. can think of it as a raw distributed database if you took a relational db and stripped away everything but the commit log.

### Partitions in Detail

![partition detail](doc-images/partition-detail.png "partition detail")

* A logical topic is represented by one or more physical log files called partitions.
* Number of partitions per topic is configurable.
* Partition is how Kafka achieves:
  * Scale
  * Fault tolerance
  * Higher levels of throughput
* Each partition is maintained on at least one or more brokers

![partition detail 2](doc-images/partition-detail-2.png "partition detail 2")

Recall in earlier demo, created `my_topic` with only a single partition and replication factor:

```bash
./opt/kafka/bin/kafka-topics.sh --create --topic my_topic \
  --replication-factor 1 \
  --partitions 1 \
  --zookeeper zookeeper:2181
```

* Each topic must have at least one partition, because that partition is the physical representation of the commit log, stored on one or more brokers.
* Each partition must fit entirely on one machine.
* If choose `--partitions 1` for a topic, this means the entire contents of the topic will only be stored on a single broker, if that node goes down, consumers/producers will be stuck unable to retrieve/publish messages. Also the topic size will be limited by the physical resources on that single broker.

**General rule:** Scalability of Kafka determined by number of partitions being managed by multiple broker nodes.

**Topic with Multiple Partitions**

```bash
./opt/kafka/bin/kafka-topics.sh --create --topic my_topic \
  --replication-factor 1 \
  --partitions 3 \
  --zookeeper zookeeper:2181
```

![multiple partitions](doc-images/multiple-partitions.png "multiple partitions")

* In this case, the single topic `my_topic` will be split across three different log files.
* Ideally, each partition will be managed by a different broker node, so in this case, we would want at least 3 broker nodes in the cluster.
* Each partition is mutually exclusive from the other, each will receive unique messages from a producer producing messages to this topic.
* Multiple partitions increase parallelism of operations such as message consumption.
* Each partition is still a time-ordered sequence of events that are appended to by producer.

**Allocating Messages Across Partitions**

How does producer split messages across the different partitions that make up the topic its producing to? Based on *partitioning scheme* that is established by producer (will cover more later). In absence of specifying a partitioning scheme, messages will be allocated to partitions based on round-robin. This is important in considering how balanced the partitions are for a given topic.

### Distributed Partition Management

![distributed partition management](doc-images/distributed-partition-management.png "distributed partition management")

- Command to create topic with `n` partitions handled by Zookeeper, which maintains metadata about the cluster.
- Zookeeper will consider the available brokers, and decide which brokers will be assigned to be the *leaders* responsible for managing a single partition within the topic.
- When a broker receives an assignment from Zookeeper to be the leader of a partition, it creates a log file for this partition. Directory where log file is located will be named based on topic name and partition number.
- Each broker also maintains a subset of the metadata that Zookeeper does, including which partitions are being managed by which brokers in the cluster.
- This means any broker can direct a producer client to the appropriate broker for writing messages to a specific partition.
- Brokers broadcast their status info to Zookeeper so that consensus is maintained across the cluster.

![publish distributed](doc-images/publish-distributed.png "publish distributed")

- When producer is preparing to produce a message to a topic, it must know the location of at least one broker in the cluster, so it can find the leaders of the topics' partitions.
- Each broker knows which partitions are owned by which leader.
- Metadata related to topic is sent back to producer, producer uses this info to send messages to the brokers that are participating in managing the partitions that make up the topic.

![consume distributed](doc-images/consume-distributed.png "consume distributed")

- Consumers operate similarly to producers, except they rely on Zookeeper more
- Consumer queries Zookeeper to determine which brokers own which partitions of a topic.
- Zookeeper also returns metadata to consumer that affects its consumption behaviour, especially critical when there are large groups of consumers sharing the consumption workload of a given topic.
- After consumer receives info about which brokers have the topic partitions, it will pull messages from the brokers, based on message offset per partition.
- Consumers may have to handle message order when consuming messages from multiple partitions, because the messages got produced to these multiple partitions at different times, so consumer may receive messages in different orders in which they were published.

**Partitioning Trade-offs**

* The greater the number of partitions, the greater the Zookeeper overhead (Zookeeper maintains in-memory registry of brokers and partitions). Mitigate by ensuring ZK ensemble is provisioned with appropriate capacity to handle large numbers of partitions.
* Message ordering can become complex. There is no global ordering of messages in a topic across partitions.
* If consuming application absolutely needs global message ordering, use a single partition (but this limits scalability).
* Alternative to above is to put order handling logic in consumer and consumer groups (covered later).
* The greater the number of partitions, the longer the leader fail-over time. It's typically in ~ms, but can add up in a large system (mitigate with multiple clusters).

### Achieving Reliability

aka Fault tolerance. Problems that could arise include:

- Broker failure
- Network issue so that broker is unreachable
- Disk failure

![broker-down](doc-images/br "broker-down")

- When ZK determines that a broker is down, it assigns another broker to take its place and updates its metadata accordingly.
- Once metadata is updated, consumers and producers can continue consuming/producing messages to the topic.
- But need redundancy between nodes to avoid data loss (recall physical log file is persisted on the broker that went down), otherwise those previous messages that were persisted on this broker would be lost.

**Replication Factor**

Recall from earlier demo, the `replication-factor` was set to 1, fine for demo but bad for production:

```bash
./opt/kafka/bin/kafka-topics.sh --create --topic my_topic \
  --replication-factor 1 \
  --partitions 1 \
  --zookeeper zookeeper:2181
```

Setting `replication-factor` to 1 means the topics' partitions only have a single replica. Increase this number to achieve:

- redundancy of messages
- cluster resiliency
- fault-tolerance

Setting `replication-factor` to some value `n` that is > 1 guarantees:

- N-1 broker failure tolerance
- 2 or 3 minimum is recommended so that a node failure or required maintenance does not impact cluster

`replication-factor` is configured on a per-topic basis

Example command to create a topic with 3 partitions and 3 replicas:

```bash
./opt/kafka/bin/kafka-topics.sh --create --topic my_topic \
  --replication-factor 3 \
  --partitions 3 \
  --zookeeper zookeeper:2181
```

![replication](doc-images/replication.png "replication")

- When replication factor is set to 3, each leader node is responsible to get peer brokers to participate in a *quorum*.
- The quorum is responsible for replicating the log to achieve requested redundancy.
- When broker that is the partition leader has a quorum, it requests its peers to start copying the partition log file.
- When all members of the replication quorum have completed their copy to achieve a full synchronized replica set, it's reported throughout the cluster that the number of *in-sync replicas* (ISR) is equal to requested replication factor for that topic and each partition within that topic.
- When ISR == replication factor, topic and each partition that makes up the topic is in a *healthy* state.
- If quorum can't be established, or ISR falls below replication factor, manual intervention may be required. Kafka will not automatically seek out a new peer to join the quorum. Cluster monitoring is required to detect this.

**Viewing Topic State**

Command to view what's happening with a topic:

```bash
./opt/kafka/bin/kafka-topics.sh --describe --topic my_topic --zookeeper zookeeper:2181
```

Output:

```
Topic: my_topic	TopicId: 4YUMeYFfR-yLgcsXX-zUUQ	PartitionCount: 1	ReplicationFactor: 1	Configs:
Topic: my_topic	Partition: 0	Leader: 1001	Replicas: 1001	Isr: 1001
```

### Demo Fault-tolerance and Resiliency

For this demo, we need 3 brokers. It will be based on this [tutorial](https://codersee.com/how-to-deploy-multiple-kafka-brokers-with-docker-compose/):

```
docker-compose -f docker-compose-multiple.yml up
```

Verify there's a zookeeper container and 3 kafka broker containers:

```
docker-compose -f docker-compose-multiple.yml ps
```

Use ZK shell to verify identity of active brokers:

```
docker exec -it zookeeper /bin/zookeeper-shell localhost:2181
> ls /brokers/ids
# Output: [1, 2, 3]
```

Connect to second broker, create a topic with a single partition and replication factor of 3:

```bash
docker exec -it kafka2 /bin/bash

# create topic
kafka-topics --bootstrap-server localhost:9092 --create --topic replicated_topic --partitions 1 --replication-factor 3

# view topic details - since number of ISRs == number of replicas -> partition and quorum managing it are in a healthy state
# NOTE - leader is node 3
kafka-topics --bootstrap-server localhost:9092 --describe --topic replicated_topic
# Topic: replicated_topic	TopicId: OSUHELIjSqWI3MxXwjk-8A	PartitionCount: 1	ReplicationFactor: 3	Configs:
# Topic: replicated_topic	Partition: 0	Leader: 3	Replicas: 3,2,1	Isr: 3,2,1
```

Create producer and produce some messages to topic: (instructor also specified `--broker-list localhost:9092`):

```
kafka-console-producer --bootstrap-server localhost:9092 --topic replicated_topic
> My Message 1
> My Message 2
> My Message 3
```

Consume messages:

```
kafka-console-consumer --bootstrap-server localhost:9092 --topic replicated_topic --from-beginning
# Outputs the messages, one on each line
```

**Simulate a node failure**

Since node 3 is the leader for the topic partition, let's take it down to see how Kafka handles it:

```
docker-compose -f docker-compose-multiple.yml stop kafka3
docker-compose -f docker-compose-multiple.yml ps
```

Status of containers after stopping kafka3:

```
  Name               Command             State                  Ports
-----------------------------------------------------------------------------------
kafka1      /etc/confluent/docker/run   Up         0.0.0.0:8097->8097/tcp, 9092/tcp
kafka2      /etc/confluent/docker/run   Up         0.0.0.0:8098->8098/tcp, 9092/tcp
kafka3      /etc/confluent/docker/run   Exit 143
zookeeper   /etc/confluent/docker/run   Up         2181/tcp, 2888/tcp, 3888/tcp
```

Connect to kafka1 and view topic details now:

```bash
docker exec -it kafka1 /bin/bash
kafka-topics --bootstrap-server localhost:9092 --describe --topic replicated_topic
# Topic: replicated_topic	TopicId: OSUHELIjSqWI3MxXwjk-8A	PartitionCount: 1	ReplicationFactor: 3	Configs:
# Topic: replicated_topic	Partition: 0	Leader: 2	Replicas: 3,2,1	Isr: 2,1
```

Notice there's a new leader 2, and ISR's are now less than replicas -> quorum is unhealthy due to missing replica. Recall we killed broker 3 so it's no longer in sync.

Note that if there had been another broker available, Kafka would add it to quorum and start replicating to it, to replace the broker that got killed. But in this demo, we only have 3 brokers so there isn't another available.

If had left consumer terminal open, it will show warnings that it couldn't fetch from broker 3, but it doesn't cause consumer to crash.

Producer terminal continues as if nothing happened, can still publish messages and consumer can still consume them.

Bring the downed node back up:

```
docker-compose -f docker-compose-multiple.yml restart kafka3
```

Connect to any node and check topic details again - leader is still 2, but this time, ISR's have increased to 3. i.e. node 3 was brought back into the quorum and had the log replicated.

```bash
docker exec -it kafka2 /bin/bash
kafka-topics --bootstrap-server localhost:9092 --describe --topic replicated_topic
# Topic: replicated_topic	TopicId: OSUHELIjSqWI3MxXwjk-8A	PartitionCount: 1	ReplicationFactor: 3	Configs:
# Topic: replicated_topic	Partition: 0	Leader: 2	Replicas: 3,2,1	Isr: 2,1,3
```

## Producing Messages with Producers

For this part, will use Ruby + Karafka instead of Java.

[Reference Non Rails Example](https://github.com/karafka/example-apps/tree/master/v2.0-non-rails)

Initial setup:

```
docker-compose up
cd project
bundle install
```

Start Karafka console to demo simple produce:

```
bundle exec karafka console
```

```ruby
Karafka.producer.produce_sync(topic: 'example', payload: { 'ping' => 'pong' }.to_json)
```

Optionally start Karafka server (which will make consumers start polling for messages):

```
bundle exec karafka server
```

Send few more messages using WaterDrop:

```
bundle exec rake waterdrop:send
```

### Intro

**Producer Internals**

Producer is a piece of software

![producer internals](doc-images/producer-internals.png "producer internals")

**Configuration**

[Kafka Producer Configs Doc](https://kafka.apache.org/documentation.html#producerconfigs)

[Karafka Configuration Doc](https://karafka.io/docs/Configuration/)

[Karafka API Doc](https://karafka.io/docs/code/karafka)

[WaterDrop API Doc](https://karafka.io/docs/code/waterdrop/)

Kafka configs are specified in `karafka.rb`, eg:

```ruby
class KarafkaApp < Karafka::App
  setup do |config|
    config.client_id = 'my_application'
    # librdkafka configuration options need to be set as symbol values
    config.kafka = {
      'bootstrap.servers': '127.0.0.1:9092'
    }
  end
end
```

Producer doesn't connect to to every broker in `bootstrap.servers` config property, just the first available one. Then it uses this broker to discover the full membership of the cluster including partition leaders.

Best practice is to specify multiple brokers in the `bootstrap.servers` list in case the first broker happens to be unavailable.

Course mentions about setting producer level config `key.serializer` and `value.serializer` but this option doesn't seem to be available in Karafka? Karafka uses [waterdrop](https://github.com/karafka/waterdrop) to produce messages. Here's list of all [config options](https://github.com/confluentinc/librdkafka/blob/master/CONFIGURATION.md). Found a note `serializer is no longer needed because Responders have been removed from Karafka` in [Upgrade doc](https://github.com/karafka/karafka/wiki/Upgrades-2.0).

Message content is encoded in binary to optimize message size.

Producer is responsible to specify how the message contents are to be encoded, so later the consumer will know how to decode them.

Karafka assumes by default that messages sent/received are JSON. [Deserialization](https://github.com/karafka/karafka/wiki/Deserialization)

To produce a message with Karafka (it picks up config from `karafka.app`):

```ruby
10.times do
  message = { 'number' => rand }.to_json
  Karafka.producer.produce_async(topic: 'counters', payload: message)
end
```

`Karafka.producer` is `WaterDrop::Producer`

The `produce_async` method only requires the `topic` and `payload`.

`message` must match serializer (Kafka defaults to JSON).

Optionally can specify `partition` when producing message:

```ruby
Karafka.producer.produce_sync(topic: 'example', payload: { 'ping' => 'pong' }.to_json, partition: 1)
```

Optionally can also specify `timestamp` when producing message:

```ruby
Karafka.producer.produce_sync(topic: 'example', payload: { 'ping' => 'pong' }.to_json, partition: 0, timestamp: 124535353325)
```

## Consuming Messages with Consumers

[Consumer Config Docs](https://kafka.apache.org/documentation.html#consumerconfigs)
