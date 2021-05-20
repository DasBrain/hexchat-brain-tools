package require hexchat

package provide dasbrain::invitejoin 1.0

namespace eval ::dasbrain::invitejoin {
	if {![info exists invited]} {
		variable invited [::hexchat::hook_print {Invited} ::dasbrain::invitejoin::invited]
	}
	if {![info exists youjoin]} {
		variable youjoin [::hexchat::hook_print {You Join} ::dasbrain::invitejoin::youjoin]
	}
	namespace export addjoin
	if {![info exists needinvite]} {
		variable needinvite [dict create]
	}
}

proc ::dasbrain::invitejoin::addjoin {channel} {
	variable needinvite
	dict set needinvite [::hexchat::prefs id] $channel 1
}

proc ::dasbrain::invitejoin::invited {words} {
	variable needinvite
	set channel [lindex $words 1]
	if {[dict exists $needinvite [::hexchat::prefs id] $channel]} {
		::hexchat::command "JOIN $channel"
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::invitejoin::youjoin {words} {
	variable needinvite
	set channel [lindex $words 2]
	if {[dict exists $needinvite [::hexchat::prefs id]]} {
		dict unset needinvite [::hexchat::prefs id] $channel
	}
	return $::hexchat::EAT_NONE
}
