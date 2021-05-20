package require hexchat
package require sqlite3

package provide dasbrain::chanopt 1.0

namespace eval ::dasbrain::chanopt {

	sqlite3 db [file join [::hexchat::getinfo configdir] chanopt.db]
	db eval {CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY, network TEXT NOT NULL, channel TEXT NOT NULL, setting TEXT)}
	db eval {CREATE UNIQUE INDEX IF NOT EXISTS settings_network_channel ON settings(network, channel)}

	if {![info exists cmd_cset]} {
		variable cmd_cset [::hexchat::hook_command CSET ::dasbrain::chanopt::cmd_cset]
	}
	
	variable settings [dict create]
	namespace export get set ccopt
	namespace ensemble create -command ::copt -map {set cset get cget register register}
}

proc ::dasbrain::chanopt::cget {network channel args} {
	set opts [db onecolumn {SELECT setting FROM settings WHERE network == $network AND channel == $channel}]
	if {[llength $args] == 0} {
		return $opts
	}
	if {[dict exists $opts {*}$args]} {
		return [dict get $opts {*}$args]
	}
	variable settings
	if {[dict exists $settings [lindex $args 0] default {*}[lrange $args 1 end]]} {
		return [dict get $settings [lindex $args 0] default {*}[lrange $args 1 end]]
	}
	return {}
}

proc ::dasbrain::chanopt::cset {network channel setting value} {
	set opts [db onecolumn {SELECT setting FROM settings WHERE network == $network AND channel == $channel}]
	variable settings
	if {[dict exists $settings $setting default] ? [dict get $settings $setting default] eq $value : $value eq {}} {
		dict unset opts $setting
	} else {
		dict set opts $setting $value
	}
	if {[dict size $opts] > 0} {
		db eval {INSERT INTO settings (network, channel, setting) VALUES ($network, $channel, $opts) ON CONFLICT(network, channel) DO UPDATE SET setting = excluded.setting}
	} else {
		db eval {DELETE FROM settings WHERE network == $network AND channel == $channel}
	}
	return
}

proc ::dasbrain::chanopt::register {name type {default {}}} {
	variable settings
	dict set settings $name [dict create type $type default $default]
}

proc ::dasbrain::chanopt::ccopt {cmd args} {
	tailcall ::copt $cmd [::hexchat::getinfo network] [::hexchat::getinfo channel] {*}$args
}

proc ::dasbrain::chanopt::cmd_cset {words words_eol} {
	set args [lindex $words_eol 2]
	if {[llength $args] == 0} {
		set opts [ccopt get]
		dict for {k v} $opts {
			::hexchat::print "$k\t$v"
		}
		variable settings
		dict for {k v} $settings {
			if {[dict exists $opts $k]} {
				continue
			}
			if {[dict exists $v default]} {
				set val [dict get $v default]
			} else {
				set val {}
			}
			::hexchat::print "$k\t$val (unset)"
		}
		return $::hexchat::EAT_ALL
	}
	set opts [list]
	foreach arg $args {
		if {[string index $arg 0] in {- +}} {
			lappend opts [string range $arg 1 end] [lsearch {- +} [string index $arg 0]]
		} else {
			lappend opts $arg
		}
	}
	foreach {k v} $opts {
		ccopt set $k $v
	}
	::hexchat::print "COPT\tSuccessfully set $opts"
	return $::hexchat::EAT_ALL
}

namespace eval :: {
	namespace import -force ::dasbrain::chanopt::ccopt
}
