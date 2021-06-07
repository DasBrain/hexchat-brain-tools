package require hexchat
package require sqlite3
package require dasbrain::channels
package require dasbrain::matcher

package provide dasbrain::users 1.0

namespace eval ::dasbrain::users {
	sqlite3 ::dasbrain::users::db [file join [::hexchat::getinfo configdir] users.db]
	db eval {CREATE TABLE IF NOT EXISTS handles (id INTEGER PRIMARY KEY, handle TEXT UNIQUE NOT NULL, comment TEXT, attrs TEXT)}
	db eval {CREATE TABLE IF NOT EXISTS handle_matchers (id INTEGER PRIMARY KEY, network TEXT NOT NULL, handle TEXT NOT NULL, matcher TEXT NOT NULL, priority INTEGER NOT NULL DEFAULT 0)}
	db eval {CREATE TABLE IF NOT EXISTS handle_capabilities (id INTEGER PRIMARY KEY, network TEXT NOT NULL, channel TEXT NOT NULL, handle TEXT NOT NULL, key TEXT NOT NULL, value DEFAULT NULL)}
	db eval {CREATE INDEX IF NOT EXISTS handle_matchers_network_prio ON handle_matchers (network, priority DESC)}
	db eval {CREATE INDEX IF NOT EXISTS handle_capabilities_network_channel_handle ON handle_capabilities (network, channel, handle)}
}

set ::dasbrain::channels::auth-provider ::dasbrain::users::provider

proc ::dasbrain::users::provider {chan userrec} {
	set handle *
	set network [::hexchat::getinfo network]
	db eval {SELECT handle as hnd, matcher FROM handle_matchers WHERE network in ('*', $network) ORDER BY priority DESC} {
		if {[::dasbrain::matcher::matches $matcher $userrec]} {
			set handle $hnd
			break
		}
	}
	if {$handle ne {*}} {
		set hndlist [list * $handle]
	} else {
		set hndlist *
	}
	set capabilites [dict create]
	# Nested loops go brrrr
	foreach hnd $hndlist {
		foreach ch [list * $chan] {
			foreach nw [list * $network] {
				db eval {SELECT key, value, value IS NULL as nv FROM handle_capabilities WHERE network == $nw AND channel == $ch AND handle == $hnd} {
					if {$nv} {
						dict unset capabilites $key
					} else {
						dict set capabilites $key $value
					}
				}
			}
		}
	}
	return [list $handle $capabilites]
}

proc ::dasbrain::users::adduser {name args} {
	# TODO: comment support
	db eval {INSERT INTO handles (handle) VALUES ($name)}
}

proc ::dasbrain::users::refresh-auth {network channel handle} {
	set cfields [::hexchat::list_fields channels]
	set ctxidx [lsearch $cfields context]
	set channelidx [lsearch $cfields channel]
	set networkidx [lsearch $cfields network]
	set typeidx [lsearch $cfields type]
	
	set origctx [::hexchat::getcontext]
	
	foreach chan [::hexchat::getlist channels] {
		if {[lindex $chan $typeidx] != 2} {continue}
		set netw [lindex $chan $networkidx]
		set cn [lindex $chan $channelidx]
		if {$network ne {*} && $network ne $netw} {continue}
		if {$channel ne {*} && $channel ne $cn} {continue}
		::hexchat::setcontext [lindex $chan $ctxidx]
		dict for {nick userrec} [::dasbrain::channels::userlist $cn] {
			if {$handle eq {*} || ([dict exists $userrec handle] && [dict get $userrec handle] eq $handle)} {
				::dasbrain::channels::do-auth $cn $userrec
			}
		}
	}
	::hexchat::setcontext $origctx
}

proc ::dasbrain::users::addmatcher {handle network matcher {priority 0}} {
	db eval {INSERT INTO handle_matchers (network, handle, matcher, priority) VALUES ($network, $handle, $matcher, $priority)}
	refresh-auth $network * *
}

proc ::dasbrain::users::delmatcher {handle network matcher} {
	db eval {DELETE FROM handle_matchers WHERE network == $network AND handle == $handle AND matcher == $matcher}
	refresh-auth $network * $handle
}

proc ::dasbrain::users::addcapability {handle network channel key value} {
	db eval {INSERT INTO handle_capabilities (network, channel, handle, key, value) VALUES ($network, $channel, $handle, $key, $value)}
	refresh-auth $network $channel $handle
}

proc ::dasbrain::users::remcapability {handle network channel key} {
	db eval {DELETE FROM handle_capabilities WHERE network == $network AND channel == $channel AND handle == $handle AND key == $key}
	refresh-auth $network $channel $handle
}
