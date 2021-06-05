package require hexchat

package require dasbrain::isupport

package provide dasbrain::modeparse 1.0

namespace eval ::dasbrain::modeparse {
	if {![info exists rawmode]} {
		variable rawmode [::hexchat::hook_server MODE ::dasbrain::modeparse::parse]
	}
	
	namespace import -force ::dasbrain::isupport::ircsplit ::dasbrain::isupport::isupport
	namespace export handler ircsplit
	if {![info exists handler]} {
		variable handler [list]
	}
}

proc ::dasbrain::modeparse::parse {words words_eol} {

	set chanmeta [isupport get CHANTYPES]

	set line [ircsplit [lindex $words_eol 1]]
	# :src MODE #channel +o target
	set channel [lindex $line 2]
	if {[string index $channel 0] ni $chanmeta} {
		# User mode change - ignore
		return $::hexchat::EAT_NONE
	}
	set plusminus +
	set from [lindex $line 0]
	set args [lrange $line 4 end]

	set chanmodes [split [isupport get CHANMODES] ,]
	set prefixes [isupport get PREFIX]
	set nickmodes [split [string range $prefixes 1 [string first ) $prefixes]] {}]
	
	set A [split [lindex $chanmodes 0] {}]; # eIbq
	set B [split [lindex $chanmodes 1] {}]; # k
	set C [split [lindex $chanmodes 2] {}]; # flj
	set D [split [lindex $chanmodes 3] {}]; # CFLMPQScgimnprstuz
	
	foreach c [split [lindex $line 3] {}] {
		if {$c in {+ -}} {
			set plusminus $c
			continue
		} elseif {$c in $nickmodes} {
			set take 1
		} elseif {$c in $A} {
			set take 1
		} elseif {$c in $B} {
			set take 1
		} elseif {$c in $C} {
			set take [string equal $c +]
		} elseif {$c in $D} {
			set take 0
		} else {
			::hexchat::print "Unknown Mode $c, assuming no parameter"
			set take 0
		}
		if {$take} {
			set args [lassign $args arg]
			process $from $channel $plusminus$c $arg
		} else {
			process $from $channel $plusminus$c {}
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::modeparse::process {from channel mode arg} {
	variable handler
	foreach h $handler {
		try {
			{*}$h $from $channel $mode $arg
		} on error {- opt} {
			::hexchat::print "Mode $h $channel $mode $arg\t[dict get $opt -errorinfo]"
		}
	}
}

proc ::dasbrain::modeparse::handler {cmd} {
	variable handler
	if {$cmd ni $handler} {
		lappend handler $cmd
	}
}