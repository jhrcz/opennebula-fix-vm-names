#!/bin/bash

# function for simple debugging condition
# use: qdebug && echo debug message
function qdebug
{
	if [ "$DEBUG" = "YES" ]
	then
		return 1
	else
		return 0
	fi
}

# be verbose and write detailed trace to logfile
qdebug && \
	set -x
qdebug && \
	exec 2>/tmp/debug-$$.log

DB="sqlite3 /var/lib/one/one.db"

# select source for detecting new name
# possible values: template / osvolume
newname_source=template

# function for running db queries
# use: dbq "dome sql query;"
function dbq
{
  echo "$1" | $DB
}

( if [ -n "$1" ]
then
	echo "$1"
else
	# 6=done, 7=failed
	#dbq "select oid from vm_pool where state not in  ( 6, 7 ) and name like 'one-%';"
	dbq "select oid from vm_pool where name like 'one-%';"
fi )| while read oid
do
	qdebug && dbq "select name from vm_pool where oid = $oid;"| sed -e "s/^/DEBUG:/"
	qdebug && dbq "select body from vm_pool where oid = $oid;"| sed -e "s/^/DEBUG:/"

	case $newname_source in

		# new volume name is determined from the main os volume name
		osvolume)
			primary_volume_name=$(dbq "select body from vm_pool where oid = $oid;"  | xmlstarlet fo | xmlstarlet sel -t -v '//VM/TEMPLATE/DISK/IMAGE')
			newname="${primary_volume_name// /_}"
			;;

		# new volume name is determined from the vm template name
		template)
			templateid=$(dbq "select body from vm_pool where oid = $oid;"  | xmlstarlet fo | xmlstarlet sel -t -v '//VM/TEMPLATE/TEMPLATE_ID')
			[ -n "$templateid" ] || continue
			newname=$(dbq "select name from template_pool where oid = $templateid;")
			newname="${newname// /_}"
			;;

	esac

	# treat any error before new name is detected
	if [ -n "$newname" ]
	then
		qdebug && \
			echo "DEBUG: $newname"
		
		# new name prefixed for make the name distinguished from directly defined names
		newname="tpl:$newname"

		# update the xml data fragment in body column
		dbq "update vm_pool set body = replace( body, '<NAME>one-$oid</NAME>', '<NAME>$newname</NAME>' ) where oid like $oid;"

		# update the name column
		dbq "update vm_pool set name = replace( name, 'one-$oid', '$newname' ) where oid like $oid;"
	fi

done

