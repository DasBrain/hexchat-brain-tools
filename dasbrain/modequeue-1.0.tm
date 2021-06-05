package require hexchat

package provide dasbrain::modequeue 1.0

namespace eval ::dasbrain::modequeue {
	if {[info exists modequeue]} {
		variable modequeue [dict create]
	}
	if {[info exists modetimer]} {
		set modetimer {}
	}
	
	namespace export pushmode flushmodes
}

proc ::dasbrain::modequeue::pushmode {channel mode {target {}}} {
	variable modequeue
	variable modetimer
	# TODO: validate
	dict set [::hexchat::prefs id] $channel [list $mode $target] 1
	if {$modetimer eq {}} {
		set modetimer [after 100 ::dasbrain::modequeue::flushmodes]
	}
}

proc ::dasbrain::modequeue::flushmodes {} {
	variable modequeue
	variable modetimer
	if {[dict size $modequeue] != 0} {
		set cinfo [::hexchat::getlist channels]
		set cfields [::hexchat::list_fields channels]
		set ididx [lsearch $cfields id]
		set maxmodesidx [lsearch $cfields maxmodes]
		set contextidx [lsearch $cfields context]
		dict for {id cdict} $modequeue {
			set ccinfo [lsearch -inline -index $ididx $cinfo $id]
			set maxmodes [lindex $ccinfo $maxmodesidx]
			::hexchat::setcontext [lindex $ccinfo $contextidx]
			dict for {chan modes} {
				set modestr "MODE $chan "
				set args {}
				set pm {}
				set modecount 0
				dict for {mst -} $cdict {
					lassign $msg modechange target
					if {$pm ne [string index $modechange 0]} {
						set pm [string index $modechange 0]
						append modestr $pm
					}
					append modestr [string index $modechange 1]
					if {$target ne {}} {
						append args " $target"
					}
					incr modecount
					if {$modecount >= $maxmodes || [string length $modestr] + [string length $args] > 400} {
						# Flush
						::hexchat::command "$modestr$args"
						set modestr "MODE $chan "
						set args {}
						set pm {}
						set modecount 0
					}
				}
				if {$modecount > 0} {
					::hexchat::command "$modestr$args"
				}
			}
			dict unset modequeue $id
		}
	}
	after cancel $modetimer
	set modetimer {}
}