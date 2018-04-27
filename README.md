## Following writing service

This is the a micro-microservice for nanotwitter. 
The service contains a messaging queue and it's listening the changes in the queue. 

The queue is for follow and unfollow only. In *config/unicorn.rb*, the queus listener is initilized. 

`
$server = FollowerServer.new(QUEUE_URL)
$server.start(QUEUE_NAME)
`

The messaging queuing technology is realized by RabbitMQ. 

The writer_server.rb did all the work.`process(follow_json)` is called everytime a new message appeared in the queue. It's going to materialize the message, which means put the coresponding relation in to database(PSQL) and cache(Radis).

The cache and database is shared with the **[User service](github.com/Fantastic-Four124/userservice)** and **[Follow service](github.com/Fantastic-Four124/nanotwitter-follow-service)**.

