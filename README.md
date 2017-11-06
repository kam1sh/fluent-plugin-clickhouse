# What is this?
It's a output plugin for [Fluentd](https://www.fluentd.org/), that sends data into [Yandex ClickHouse](https://clickhouse.yandex) database. By now it supports buffered output (*I still don't know how*) and handling few exceptions.  
# How to use it?
I'm not a ruby programmer who knows how to write gems, so **just put [out_clickhouse.rb](out_clickhouse.rb) to /etc/td-agent/plugin**.  
There's example td-agent.conf:
```
<source>
    @type http
    port 8888
</source>
<match inp>
    @type clickhouse
    host 127.0.0.1
    port 8123
    table FLUENT
    fields _DATE,_DATETIME,tag,number # _DATE and _DATETIME is a internal plugin fields.
</match>
```
Before launching td-agent, create table into ClickHouse:  
`CREATE TABLE default.FLUENT ( Date Date,  DateTime DateTime,  Str String,  Num Int32) ENGINE = MergeTree(Date, Date, DateTime, 8192)`  
Start td-agent and send a few events to fluentd:  
```
curl -X POST -d 'json={"number":1}' http://localhost:8888/inp
curl -X POST -d 'json={"number":2}' http://localhost:8888/inp
curl -X POST -d 'json={"number":3}' http://localhost:8888/inp
```
After a few seconds, when buffer flushes, in ClickHouse you could see this:
```:) SELECT * FROM FLUENT ;  
┌───────Date─┬────────────DateTime─┬─Str─┬─Num─┐  
│ 2017-11-06 │ 2017-11-06 14:42:03 │ inp │   1 │  
│ 2017-11-06 │ 2017-11-06 14:42:06 │ inp │   2 │  
│ 2017-11-06 │ 2017-11-06 14:42:09 │ inp │   3 │  
└────────────┴─────────────────────┴─────┴─────┘  
```
# Wow, it doesn't even support HTTP auth  
Yes, and besides auth, there's still a work to do:  
* SSL
* Timezones that doesn't suck
* GZIP. ClickHouse supports compressing, so why not?
* and more
