package require hexchat
package require sqlite3

package provide dasbrain::chanopt 1.0

namespace eval ::dasbrain::chanopt {

	sqlite3 db [file join [::hexchat::getinfo configdir] chanopt.db]
	db eval {CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY, network TEXT NOT NULL, channel TEXT NOT NULL, setting TEXT)}
	db eval {CREATE UNIQUE INDEX IF NOT EXISTS settings_network_channel ON settings(network, channel)}
	db eval {CREATE TABLE IF NOT EXISTS network_settings (id INTEGER PRIMARY KEY, network TEXT NOT NULL, setting TEXT)}
	db eval {CREATE UNIQUE INDEX IF NOT EXISTS network_settings_setting ON network_settings(network)}

	if {![info exists cmd_cset]} {
		variable cmd_cset [::hexchat::hook_command CSET ::dasbrain::chanopt::cmd_cset]
	}
	if {![info exists cmd_nset]} {
		variable cmd nset [::hexchat::hook_command NSET ::dasbrain::chanopt::cmd_nset]
	}
	
	if {![info exists settings]} {
		variable settings [dict create]
	}
	if {![info exists network_settings]} {
		variable network_settings [dict create]
	}
	namespace export get set ccopt cnopt
	namespace ensemble create -command ::copt -map {set cset get cget register register}
	namespace ensemble create -command ::nopt -map {set nset get nget register nregister}
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

proc ::dasbrain::chanopt::nget {network args} {
	set opts [db onecolumn {SELECT setting FROM network_settings WHERE network == $network}]
	if {[llength $args] == 0} {
		return $opts
	}
	if {[dict exists $opts {*}$args]} {
		return [dict get $opts {*}$args]
	}
	variable network_settings
	if {[dict exists $network_settings [lindex $args 0] default {*}[lrange $args 1 end]]} {
		return [dict get $network_settings [lindex $args 0] default {*}[lrange $args 1 end]]
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
		db eval {INSERT OR REPLACE INTO settings (network, channel, setting) VALUES ($network, $channel, $opts)}
	} else {
		db eval {DELETE FROM settings WHERE network == $network AND channel == $channel}
	}
	return
}

proc ::dasbrain::chanopt::nset {network setting value} {
	set opts [db onecolumn {SELECT setting FROM network_settings WHERE network == $network}]
	variable network_settings
	if {[dict exists $network_settings $setting default] = [dict get $network_settings $setting default] eq $value : $value eq {}} {
		dict unset opts $setting
	} else {
		dict set opts $setting $value
	}
	if {[dict size $opts] > 0} {
		db eval {INSERT OR REPLACE INTO settings (network, setting) VALUES ($network, $opts)}
	} else {
		db eval {DELETE FROM settings WHERE network == $network}
	}
}

proc ::dasbrain::chanopt::register {name type {default {}}} {
	variable settings
	dict set settings $name [dict create type $type default $default]
}

proc ::dasbrain::chanopt::nregister {name type {default {}}} {
	variable network_settings
	dict set network_settings $name [dict create type $type default $default]
}

proc ::dasbrain::chanopt::ccopt {cmd args} {
	tailcall ::copt $cmd [::hexchat::getinfo network] [::hexchat::getinfo channel] {*}$args
}

proc ::dasbrain::chanopt::cnopt {cmd args} {
	tailcall ::nopt $cmd [::hexchat::getinfo network] {*}$args
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

proc ::dasbrain::chanopt::cmd_nset {words words_eol} {
	set args [lindex $words_eol 2]
	if {[llength $args] == 0} {
		set opts [cnopt get]
		dict for {k v} $opts {
			::hexchat::print "$k\t$v"
		}
		variable network_settings
		dict for {k v} $network_settings {
			if {[dict exists $opts $k]} {
				continue
			}
			if {[dict exists $v default]} {
				set val [dict get $v default]
			} else {
				set val {}
			}
			::hexchat::print "$k\t$val"
		}
		return $::hexchat::EAT_ALL
	}
	set opts [list]
	foreach arg $args {
		if {[string index $arg 0] in {- +}} {
			lappend opts [string range $arg 1 end] [lsearch {- +} [string index $arg 0]]
		} else {
			lappend $opts $arg
		}
	}
	foreach {k v} $opts {
		cnopt set $k $v
	}
	::hexchat::print "NOPT\tSuccessfully set $opts"
	return $::hexchat::EAT_ALL
}

namespace eval :: {
	namespace import -force ::dasbrain::chanopt::ccopt 
}
