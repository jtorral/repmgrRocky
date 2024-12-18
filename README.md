## repmgrRocky

This is a Docker environemnt to run Postgres with repmgr for learning, testing, playing or breaking things.

My prefered method of replication management is to use Patroni, but since repmgr is still out there and supported, I thought I would put this package together
as a way to help get started and understanding the trechnology. With that said, this setup consists of the following:

* Rocky linux 8
* PostgreSQL 16.4
* repmgr 5.4.1

## TL;DR;

**Note: ssh keys in this rep are ok to be public here since they are for using inside your docker container for testing only.**

### Clone the repo to your local machine

```git clone git@github.com:jtorral/repmgrRocky.git```


### Build the docker image

```docker build -t repmgr_rocky8```


### Running the container's ( more than 1 is needed to replicate postgres )

Runningthe containers is pretty straight forward. Just keep in mind the following:

Your container names should be consistent and end in a number preceeded by a hyphen.

for example, if you wanted to setup two or three postgres containers in this environment you could name them something like

* pgdemo-1
* pgdemo-2
* pgdemo-3

Notice how they end in -1, -2 and -3

These numbers are used to identify which container will be the initial primary db server. As you guessed it, the server ending in -1 will be the primary.
sed on the role and server name, primary or standby, config files willbe created and commands executed.

**Immportant!**

**Now that you know the naming convention, make sure you use no hyphens in the node name other than at the end to give it a unique name like buuba-3**



Security for this is minimal since this is a playground. Passwords are the same as the usernames.

* postgres user password is 'postgres'
* repmgr user password is 'repmgr'

Additionally, a .pgpass file is created with a minimum of 6 entries based on the server name you create.

```
pgdemo-1:5432:replication:repmgr:repmgr
pgdemo-1:5432:repmgr:repmgr:repmgr
pgdemo-2:5432:replication:repmgr:repmgr
pgdemo-2:5432:repmgr:repmgr:repmgr
pgdemo-3:5432:replication:repmgr:repmgr
pgdemo-3:5432:repmgr:repmgr:repmgr
pgdemo-4:5432:replication:repmgr:repmgr
pgdemo-4:5432:repmgr:repmgr:repmgr
pgdemo-5:5432:replication:repmgr:repmgr
pgdemo-5:5432:repmgr:repmgr:repmgr
pgdemo-6:5432:replication:repmgr:repmgr
pgdemo-6:5432:repmgr:repmgr:repmgr
```

The only thing to remember when running the containers is to set a different port for them and their names.

For example

**pgdemo-1**

```
docker run -p 6432:5432 --env=PGPASSWORD=postgres -v pgdemo-1:/pgdata --network=pgnet --hostname=pgdemo-1 --shm-size=1g --name=pgdemo-1 -d repmgr_rocky8
```

**pgdemo-2**

```
docker run -p 6433:5432 --env=PGPASSWORD=postgres -v pgdemo-2:/pgdata --network=pgnet --hostname=pgdemo-2 --shm-size=1g --name=pgdemo-2 -d repmgr_rocky8
```

The above will run two containers **pgdemo-1** and **pgdemo-2** on two different ports for postgres. **6432** for pgdemo-1 and **6433** for pgdemo-2


**Always start the first node first and wait for it to be running before starting others**

### Special note !!!

if you start the 2nd or 3rd or anytother containr like described above for pgdemo-2, it will automatically set itself up as a replica of the first continer with a name ending in -1

**HOWEVER**

If you start the container and specify the environment variable STREAMFROM like this ...

```
docker run -p 6434:5432 --env=PGPASSWORD=postgres --env=STREAMFROM=pgdemo-2 -v pgdemo-3:/pgdata --network=pgnet --hostname=pgdemo-3 --shm-size=1g --name=pgdemo-3 -d repmgr_rocky8
```

It will set itself up as a replica of the node defined by STREAMFROM.


```
docker ps

CONTAINER ID   IMAGE           COMMAND                  CREATED         STATUS         PORTS                                                                                  NAMES
44109c70905f   repmgr_rocky8   "/bin/bash -c /entry…"   7 minutes ago   Up 7 minutes   80/tcp, 0.0.0.0:6434->5432/tcp, [::]:6434->5432/tcp                                    pgdemo-3
77dc67083dec   repmgr_rocky8   "/bin/bash -c /entry…"   8 minutes ago   Up 8 minutes   80/tcp, 0.0.0.0:6433->5432/tcp, [::]:6433->5432/tcp                                    pgdemo-2
67538a88651b   repmgr_rocky8   "/bin/bash -c /entry…"   8 minutes ago   Up 8 minutes   80/tcp, 0.0.0.0:6432->5432/tcp, [::]:6432->5432/tcp                                    pgdemo-1

```

### What happened ?

* We run the first container
* We installed all the necessary packages
* We initialize an empty database on pgdemo-1 because its designated as the initial primary due to it's name ending in -1
* We create the repmgr user and database along with some initial Postgres config files ```/pgdata/16/data/pg_custom.conf```
* We create the ```/etc/repmgr.conf``` 
* We register the node as a primary

```
waiting for server to start....2024-11-18 03:00:47.481 UTC [] [36]: [1-1] user=,db=,host= LOG:  redirecting log output to logging collector process
2024-11-18 03:00:47.481 UTC [] [36]: [2-1] user=,db=,host= HINT:  Future log output will appear in directory "log".
 done
server started
ALTER ROLE
CREATE ROLE
ALTER ROLE
CREATE DATABASE
INFO: connecting to primary database...
NOTICE: attempting to install extension "repmgr"
NOTICE: "repmgr" extension successfully installed
NOTICE: primary node record (ID: 1) registered
```

* We start the 2nd container
* This time it knows it's not a primary and sets itself up as a standby

```
.
.
INFO: creating directory "/pgdata/16/data"...
NOTICE: starting backup (using pg_basebackup)...
HINT: this may take some time; consider using the -c/--fast-checkpoint option
INFO: executing:
  pg_basebackup -l "repmgr base backup"  -D /pgdata/16/data -h pgdemo-1 -p 5432 -U repmgr -X stream --checkpoint=fast
NOTICE: standby clone (using pg_basebackup) complete
NOTICE: you can now start your PostgreSQL server
HINT: for example: pg_ctl -D /pgdata/16/data start
HINT: after starting the server, you need to register this standby with "repmgr standby register"
waiting for server to start....2024-11-18 03:01:51.940 UTC [] [26]: [1-1] user=,db=,host= LOG:  redirecting log output to logging collector process
2024-11-18 03:01:51.940 UTC [] [26]: [2-1] user=,db=,host= HINT:  Future log output will appear in directory "log".
 done
server started
INFO: connecting to local node "pgdemo-2" (ID: 2)
INFO: connecting to primary database
WARNING: --upstream-node-id not supplied, assuming upstream node is primary (node ID: 1)
INFO: standby registration complete
NOTICE: standby node "pgdemo-2" (ID: 2) successfully registered
```

At this point we can add more nodes if needed, keeping in mind the port numbers and names

In this case we added pgdemo-3 streaming from pgdemo-2


```
.
.
.
INFO: executing:
  pg_basebackup -l "repmgr base backup"  -D /pgdata/16/data -h pgdemo-2 -p 5432 -U repmgr -X stream --checkpoint=fast
NOTICE: standby clone (using pg_basebackup) complete
NOTICE: you can now start your PostgreSQL server
HINT: for example: pg_ctl -D /pgdata/16/data start
HINT: after starting the server, you need to register this standby with "repmgr standby register"
waiting for server to start....2024-11-18 07:13:42.403 UTC [] [29]: [1-1] user=,db=,host= LOG:  redirecting log output to logging collector process
2024-11-18 07:13:42.403 UTC [] [29]: [2-1] user=,db=,host= HINT:  Future log output will appear in directory "log".
 done
server started
INFO: connecting to local node "pgdemo-3" (ID: 3)
INFO: connecting to primary database
INFO: standby registration complete
NOTICE: standby node "pgdemo-3" (ID: 3) successfully registered
```




### Some basic commands ....

**Show cluster info from inside a container**

```
[postgres@pgdemo-1 ~]$ repmgr -f /etc/repmgr.conf cluster show

 ID | Name     | Role    | Status    | Upstream | Location | Priority | Timeline | Connection string                                                        
----+----------+---------+-----------+----------+----------+----------+----------+---------------------------------------------------------------------------
 1  | pgdemo-1 | primary | * running |          | default  | 100      | 1        | host=pgdemo-1 user=repmgr password=repmgr dbname=repmgr connect_timeout=2
 2  | pgdemo-2 | standby |   running | pgdemo-1 | default  | 100      | 1        | host=pgdemo-2 user=repmgr password=repmgr dbname=repmgr connect_timeout=2
```

**Show cluster info from outside a container (container host)**

```                                                                                                                                                                                                                
docker exec -it pgdemo-1 sudo -u postgres /usr/pgsql-16/bin/repmgr -f /etc/repmgr.conf cluster show

 ID | Name     | Role    | Status    | Upstream | Location | Priority | Timeline | Connection string                                                        
----+----------+---------+-----------+----------+----------+----------+----------+---------------------------------------------------------------------------
 1  | pgdemo-1 | primary | * running |          | default  | 100      | 1        | host=pgdemo-1 user=repmgr password=repmgr dbname=repmgr connect_timeout=2
 2  | pgdemo-2 | standby |   running | pgdemo-1 | default  | 100      | 1        | host=pgdemo-2 user=repmgr password=repmgr dbname=repmgr connect_timeout=2
 3  | pgdemo-3 | standby |   running | pgdemo-2 | default  | 100      | 1        | host=pgdemo-3 user=repmgr password=repmgr dbname=repmgr connect_timeout=2

```



More info coming soon ......






