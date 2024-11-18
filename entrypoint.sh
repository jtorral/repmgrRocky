#!/bin/bash

if [ ! -f "/pgdata/16/data/PG_VERSION" ]
then 
        thisHost=$(hostname)

        ### role of db baseded on hostname

        role=$(echo $thisHost | cut -f2 -d "-")
        hostPrefix=$(echo $thisHost | cut -f1 -d "-")
        primaryHost="${hostPrefix}-1"

        echo -e "node_id=$role" > /etc/repmgr.conf
        echo -e "node_name=$thisHost" >> /etc/repmgr.conf
        echo -e "conninfo='host=$thisHost user=repmgr password=repmgr dbname=repmgr connect_timeout=2' " >> /etc/repmgr.conf
        echo -e "data_directory='/pgdata/16/data'" >> /etc/repmgr.conf
        echo -e "pg_basebackup_options='--checkpoint=fast'" >> /etc/repmgr.conf

        cp /pgsqlProfile /var/lib/pgsql/.pgsql_profile
        chmod 666 /etc/repmgr.conf
        chown postgres:postgres /etc/repmgr.conf


        ### If it's a primary, init the db otherwise, don't populate data dir for repmgr to setup clone
        if [ $role -eq 1 ]; then

           sudo -u postgres /usr/pgsql-16/bin/initdb -D /pgdata/16/data
           echo "include = 'pg_custom.conf'" >> /pgdata/16/data/postgresql.conf

           cp /pg_custom.conf /pgdata/16/data/
           cp /pg_hba.conf /pgdata/16/data/

           chown postgres:postgres /var/lib/pgsql/.pgsql_profile
           chown postgres:postgres /pgdata/16/data/pg_custom.conf
           chown postgres:postgres /pgdata/16/data/pg_hba.conf
   
           ###  Start postgres and create some roles and voodoo
   
           sudo -u postgres /usr/pgsql-16/bin/pg_ctl -D /pgdata/16/data start
           sudo -u postgres psql -c "ALTER ROLE postgres PASSWORD 'postgres';"
           sudo -u postgres psql -c "CREATE ROLE repmgr WITH SUPERUSER LOGIN PASSWORD 'repmgr';"
           sudo -u postgres psql -c 'ALTER USER repmgr SET search_path TO repmgr, "$user", public;' 
           sudo -u postgres psql -c "CREATE DATABASE repmgr WITH OWNER repmgr;"
       fi

        ### --- Lets create pgpass for repmgr to use. Pre populate with a few nodes
        ### --- Same password. Or just trust in pg_hba.conf

        for i in {1..6}; 
        do
           dbhost="${hostPrefix}-${i}"
           echo -e "${dbhost}:5432:replication:repmgr:repmgr"  >> /var/lib/pgsql/.pgpass
           echo -e "${dbhost}:5432:repmgr:repmgr:repmgr"  >> /var/lib/pgsql/.pgpass
        done

        chmod 600 /var/lib/pgsql/.pgpass
        chown postgres:postgres /var/lib/pgsql/.pgpass
   
        ### --- If this is a primary based on hostname ending in -1
        ### --- db should have been started above when identified as a primary role

        if [ $role -eq 1 ]; then
           sudo -u postgres /usr/pgsql-16/bin/repmgr -f /etc/repmgr.conf primary register
        fi

        ### --- If its a standby, lets clone it form the primary
        if [ $role -gt 1 ]; then
           if [ -z "${STREAMFROM}" ]; then
              sudo -u postgres /usr/pgsql-16/bin/repmgr -h $primaryHost -U repmgr -d repmgr -f /etc/repmgr.conf standby clone
              sudo -u postgres /usr/pgsql-16/bin/pg_ctl -D /pgdata/16/data start
              sudo -u postgres /usr/pgsql-16/bin/repmgr -f /etc/repmgr.conf standby register
           else
              upstreamId=$(echo $STREAMFROM | cut -f2 -d "-")
              sudo -u postgres /usr/pgsql-16/bin/repmgr -h $STREAMFROM -U repmgr -d repmgr -f /etc/repmgr.conf --upstream-node-id=$upstreamId standby clone
              sudo -u postgres /usr/pgsql-16/bin/pg_ctl -D /pgdata/16/data start
              sudo -u postgres /usr/pgsql-16/bin/repmgr -f /etc/repmgr.conf --upstream-node-id=$upstreamId standby register
           fi
        fi

else
        ### -- Jusat start postgres if the database was already there before

        sudo -u postgres /usr/pgsql-16/bin/pg_ctl -D /pgdata/16/data start
fi

exec tail -f /dev/null
