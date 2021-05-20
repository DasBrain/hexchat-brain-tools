package require hexchat
package require dasbrain::chanopt

package provide dasbrain::autorejoin 1.0

namespace eval ::dasbrain::autorejoin {
	::dasbrain::chanopt::register autorejoin flag 0
	if {![info exists youkicked]} {
		variable youkicked [::hexchat::hook_print {You Kicked} ::dasbrain::autorejoin::youkicked]
	}
}

proc ::dasbrain::autorejoin::youkicked {words} {
	set network [::hexchat::getinfo network]
	set channel [lindex $words 2]
	if {[copt get $network $channel autorejoin]} {
		::hexchat::command "RAW JOIN $channel"
	}
	return $::hexchat::EAT_NONE
}

