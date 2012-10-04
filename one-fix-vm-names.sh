#!/bin/bash
set -x
exec 2>/tmp/$$.log

DB="sqlite3 /var/lib/one/one.db"

function dbq
{
  echo "$1" | $DB
}

#dbq "select oid from vm_pool where state = 1 or state = 3 and name like 'one-%';" | while read oid
( if [ -n "$1" ]
then
	echo "$1"
else
	dbq "select oid from vm_pool where name like 'one-%';"
fi )| while read oid
do
	dbq "select name from vm_pool where oid = $oid;"| sed -e "s/^/DEBUG:/"
	dbq "select body from vm_pool where oid = $oid;"| sed -e "s/^/DEBUG:/"

        #primary_volume_name=$(dbq "select body from vm_pool where oid = $oid;"  | xmlstarlet fo | xmlstarlet sel -t -v '//VM/TEMPLATE/DISK/IMAGE')
	#newname="${primary_volume_name// /_}"

	templateid=$(dbq "select body from vm_pool where oid = $oid;"  | xmlstarlet fo | xmlstarlet sel -t -v '//VM/TEMPLATE/TEMPLATE_ID')
	[ -n "$templateid" ] || continue
	newname=$(dbq "select name from template_pool where oid = $templateid;")
	newname="${newname// /_}"

	if [ -n "$newname" ]
	then
		newname="tpl:$newname"
		dbq "update vm_pool set body = replace( body, '<NAME>one-$oid</NAME>', '<NAME>$newname</NAME>' ) where oid like $oid;"
		dbq "update vm_pool set name = replace( name, 'one-$oid', '$newname' ) where oid like $oid;"
	fi

done

