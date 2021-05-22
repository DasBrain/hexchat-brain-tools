package require hexchat
package require sqlite3

package provide dasbrain::contextbuttons 1.0

namespace eval ::dasbrain::contextbuttons {
	sqlite3 ::dasbrain::contextbuttons::db [file join [::hexchat::getinfo configdir] contextbuttons.db]
	db eval {CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY, name TEXT UNIQUE, value TEXT)}
	db eval {CREATE TABLE IF NOT EXISTS groups (id INTEGER PRIMARY KEY, name TEXT UNIQUE, expression TEXT NOT NULL)}
	db eval {CREATE TABLE IF NOT EXISTS buttons (id INTEGER PRIMARY KEY, bgroup TEXT NOT NULL, name TEXT NOT NULL, command TEXT NOT NULL)}
	db eval {CREATE INDEX IF NOT EXISTS button_groups ON buttons (bgroup)}
	
	variable lastgroups {}
	
	if {![info exists focus_hook]} {
		variable focus_hook [::hexchat::hook_print {Focus Tab} ::dasbrain::contextbuttons::onfocus]
	}
	
	apply {{} {
		db eval {SELECT name, value FROM settings} {
			set dasbrain::contextbuttons::$name $value
		}
	} ::dasbrain::contextbuttons}
}



proc ::dasbrain::contextbuttons::onfocus {args} {
	set channel [::hexchat::getinfo channel]
	set isquery [isquery]
	set network [::hexchat::getinfo network]
	set nick [::hexchat::getinfo nick]
	set groups [list]
	db eval {SELECT name, expression FROM groups} {
		if $expression {
			lappend groups $name
		}
	}
	variable lastgroups
	if {[dict exists $lastgroups $isquery]} {
		set lg [dict get $lastgroups $isquery]
	} else {
		set lg {}
	}
	foreach g $lg {
		if {$g ni $groups} {
			db eval {SELECT name FROM buttons WHERE bgroup == $g} {
				::hexchat::command "DELBUTTON [escape $name]"
			}
		}
	}
	foreach g $groups {
		if {$g ni $lg} {
			db eval {SELECT name, command FROM buttons WHERE bgroup == $g} {
				::hexchat::command "ADDBUTTON [escape $name] $command"
			}
		}
	}
	dict set lastgroups $isquery $groups
	db eval {INSERT INTO settings (name, value) VALUES ("lastgroups", $lastgroups) ON CONFLICT(name) DO UPDATE SET value = excluded.value}
	return $::hexchat::EAT_NONE
}

proc :.dasbrain::contextbuttons::isop {{nick -}} {
	if {$nick eq {-}} {set nick [::hexchat::getinfo nick]}
	set userfields [::hexchat::list_fields users]
	set prefixidx [lsearch $userfields prefix]
	set nickidx [lsearch $userfields nick]
	set nickinfo [lsearch -inline -index $nickidx [::hexchat::getlist users] $nick]
	# We treat everything except voice and none as op.
	return [expr {[lindex $nickinfo $prefixidx] ni {{} +}}]
}

proc ::dasbrain::contextbuttons::escape {str} {
	return "\"[string map [list \" \"\"] $str]\""
}

proc ::dasbrain::contextbuttons::isquery {} {
	set fields [::hexchat::list_fields channels]
	return [expr {[lindex [lsearch -inline -index [lsearch $fields context] [::hexchat::getlist channels] [::hexchat::getcontext]] [lsearch $fields type]] == 3}]
}
