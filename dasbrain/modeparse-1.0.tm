package require hexchat

package provide dasbrain::modeparse 1.0

namespace eval ::dasbrain::modeparse {
	if {![info exists rawmode]} {
		variable rawmode [::hexchat::hook_server MODE ::dasbrain::modeparse::parse]
	}
	
	namespace export handler ircsplit
	if {![info exists handler]} {
		variable handler [list]
	}
}

proc ::dasbrain::modeparse::parse {words words_eol} {

	set cfields [::hexchat::list_fields channels]
	set cinfo [lsearch -inline -index [lsearch $cfields id] [::hexchat::getlist channels] [::hexchat::prefs id]]
	set chanmeta [split [lindex $cinfo [lsearch $cfields chantypes]] {}]

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
	

	set chanmodes [split [lindex $cinfo [lsearch $cfields chanmodes]] ,]
	set nickmodes [split [lindex $cinfo [lsearch $cfields nickmodes]] {}]
	
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

proc ::dasbrain::modeparse::ircsplit {str} {
	set res {}
	if {[string index $str 0] eq ":"} {
		lappend res [string range $str 1 [set first [string first " " $str]]-1]
		set str [string range $str 1+$first end]
	} else {
		lappend res {}
	}
	if {[set pos [string first " :" $str]] != -1} {
		lappend res {*}[split [string range $str 0 ${pos}-1]]
		lappend res [string range $str 2+$pos end]
	} else {
		lappend res {*}[split $str]
	}
	return $res
}