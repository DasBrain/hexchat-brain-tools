package require hexchat
package require dasbrain::chanopt
package require dasbrain::modeparse

package provide dasbrain::need 1.0

namespace eval ::dasbrain::need {
	variable modenames {
		q owner
		a admin
		o op
		h hop
		v voice
	}


	::dasbrain::chanopt::register wantmode string {}
	::dasbrain::modeparse::handler ::dasbrain::need::modechange

	if {![info exists banned]} {
		variable banned [::hexchat::hook_print {Banned} ::dasbrain::need::banned]
	}
	if {![info exists needinvite]} {
		variable needinvite [::hexchat::hook_print {Invite} ::dasbrain::need::needinvite]
	}
	if {![info exists needlimitredir]} {
		variable needlimitredir [::hexchat::hook_server {470} ::dasbrain::need::needlimitredir]
	}
	if {![info exists needlimit]} {
		variable needlimit [::hexchat::hook_print {User Limit} ::dasbrain::need::needlimit]
	}
	if {![info exists needkey]} {
		variable needkey [::hexchat::hook_print {Keyword} ::dasbrain::need::needkey]
	}
	if {![info exists timer]} {
		variable timer [::hexchat::hook_timer 60000 ::dasbrain::need::checkops]
	}
	if {![info exists handler]} {
		variable handler [list]
	}
	namespace export handler
}

proc ::dasbrain::need::banned {words} {
	set channel [lindex $words 1]
	need unban $channel
	need invite $channel
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::need::needinvite {words} {
	set channel [lindex $words 1]
	need invite $channel
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::need::needlimit {words} {
	set channel [lindex $words 1]
	need invite $channel
	return $::hexchat::EAT_NONE
}

# >> :uk.technet.xi.ht 470 DasBrain #John #test :[Link] Cannot join channel #John (channel has become full) -- transferring you to #test
proc ::dasbrain::need::needlimitredir {words words_eol} {
	set channel [lindex $words 3]
	need invite $channel
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::need::needkey {words} {
	set channel [lindex $words 1]
	need key $channel
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::need::handler {cmd} {
	variable handler
	if {$cmd ni $handler} {
		lappend handler $cmd
	}
}

proc ::dasbrain::need::checkops {} {
	variable modenames
	set cfields [::hexchat::list_fields channels]
	set networkidx [lsearch $cfields network]
	set channelidx [lsearch $cfields channel]
	set contextidx [lsearch $cfields context]
	set nickmodesidx [lsearch $cfields nickmodes]
	set nickprefixesidx [lsearch $cfields nickprefixes]
	
	set ufields [::hexchat::list_fields users]
	set nickidx [lsearch $ufields nick]
	set prefixidx [lsearch $ufields prefix]

	foreach chan [::hexchat::getlist channels] {
		set network [lindex $chan $networkidx]
		set channel [lindex $chan $channelidx]
		set wanted [copt get $network $channel wantmode]
		if {$wanted eq {}} {
			continue
		}
		::hexchat::setcontext [lindex $chan $contextidx]
		set uinfo [lsearch -inline -index $nickidx [::hexchat::getlist users] [::hexchat::getinfo nick]]
		set haveprefix [lindex $uinfo $prefixidx]
		if {$haveprefix ne {}} {
			set havemodeidx [string first $haveprefix [lindex $chan $nickprefixesidx]]
		} else {
			set havemodeidx [string length [lindex $chan $nickprefixesidx]]
		}
		set wantmodeidx [string first $wanted [lindex $chan $nickmodesidx]]
		if {$wantmodeidx < $havemodeidx} {
			set wantedname [dict get $modenames $wanted]
			need $wantedname $channel
		}
	}
	return 1
}

proc ::dasbrain::need::need {what channel} {
	variable handler
	foreach h $handler {
		try {
			{*}$h $what $channel
		} on error {- opt} {
			::hexchat::print "Need $what $h\t[dict get $opt -errorinfo]"
		}
	}
}

proc ::dasbrain::need::modechange {from channel mode arg type} {
	if {[string index $mode 0] ne {-}} {
		return
	}
	variable modenames
	set removedmode [string index $mode 1]
	if {![dict exists $modenames $removedmode]} {
		return
	}
	if {[::hexchat::nickcmp $arg [::hexchat::getinfo nick]] != 0} {
		return
	}
	set wanted [copt get [::hexchat::getinfo network] $channel wantmode]
	if {$wanted eq {}} {
		return
	}
	
	if {$wanted eq $removedmode} {
		need [dict get $modenames $wanted] $channel
	} elseif {$removedmode eq {o} && $wanted in {q a}} {
		need op $channel
	}
}