package require dasbrain::modequeue
package require dasbrain::users
package require dasbrain::channels
package require dasbrain::modeparse
package require dasbrain::isupport

package provide dasbrain::automode 1.0

namespace eval ::dasbrain::automode {
	::dasbrain::channels::on-event gotops ::dasbrain::automode::gotops
	::dasbrain::channels::on-event chghandle ::dasbrain::automode::chghandle
	
	::dasbrain::modeparse::handler ::dasbrain::automode::mode-change
	
	namespace import -force ::dasbrain::isupport::isupport ::dasbrain::modequeue::pushmode
}

proc ::dasbrain::automode::gotops {chan} {
	set prefix [isupport get PREFIX]
	set bridx [string first ) $prefix]
	set umodes [string range $prefix 1 $bridx-1]
	set prefix [string range $prefix $bridx+1 end]
	set mpmap [dict create]
	foreach m [split $umodes {}] p [split $prefix {}] {
		dict set mpmap $m $p
	}
	dict for {nick userrec} [::dasbrain::channels::userlist $chan] {
		if {[dict exists $userrec caps automode]} {
			foreach am [split [dict get $userrec caps automode] {}] {
				if {![dict exists $mpmap $am]} {continue}
				if {[dict exists $userrec prefix [dict get $mpmap $am]]} {continue}
				pushmode $chan +$am [dict get $userrec nick]
			}
		}
	}
}

proc ::dasbrain::automode::chghandle {chan userrec} {
	if {![dict exists $userrec caps automode]} {
		return
	}
	if {![::dasbrain::channels::meop $chan]} {return}
	set prefix [isupport get PREFIX]
	set bridx [string first ) $prefix]
	set umodes [string range $prefix 1 $bridx-1]
	set prefix [string range $prefix $bridx+1 end]
	set mpmap [dict create]
	foreach m [split $umodes {}] p [split $prefix {}] {
		dict set mpmap $m $p
	}
	foreach am [split [dict get $userrec caps automode] {}] {
		if {![dict exists $mpmap $am]} {continue}
		if {[dict exists $userrec prefix [dict get $mpmap $am]]} {continue}
		pushmode $chan +$am [dict get $userrec nick]
	}
}

proc ::dasbrain::automode::mode-change {from chan mode arg type} {
	if {$type ne {prefix}} {return}
	if {[string index $mode 0] ne {-}} {return}
	if {![::dasbrain::channels::meop $chan]} {return}
	set fromnick [::dasbrain::channels::nuh2nick $from]
	# Use channels directly, as the target user might not be on the channel (ChanServ)
	if {![dict exist $::dasbrain::channels::channels [::hexchat::prefs id] $chan users $fromnick]} {
		# TODO: handle this stuff
		return
	}
	if {[dict exists [::dasbrain::channels::userrec $chan $fromnick] caps nofight]} {
		return
	}
	set userrec [::dasbrain::channels::userrec $chan $arg]
	if {![dict exists $userrec caps protectmode]} {return}
	set mc [string index $mode 1]
	if {$mc in [split [dict get $userrec caps protectmode] {}]} {
		pushmode $chan +$mc $arg
	}
}