#!/bin/bash
set -x

DB="sqlite3 /var/lib/one/one.db"

function dbq
{
  echo "$1" | $DB
}

dbq "select oid from vm_pool where state = 1 and name like 'one-%';" | while read oid
do
	dbq "select name from vm_pool where oid = $oid;"| sed -e "s/^/DEBUG:/"
	dbq "select body from vm_pool where oid = $oid;"| sed -e "s/^/DEBUG:/"

	primary_volume_name=$(dbq "select body from vm_pool where oid = $oid;"  | xmlstarlet fo | xmlstarlet sel -t -v '//VM/TEMPLATE/DISK/IMAGE')
	newname="${primary_volume_name// /_}"

	dbq "update vm_pool set body = replace( body, '<NAME>one-$oid</NAME>', '<NAME>$newname</NAME>' ) where oid like $oid;"
	dbq "update vm_pool set name = replace( name, 'one-$oid', '$newname' ) where oid like $oid;"

done

