package require hexchat

package require dasbrain::modequeue
package require dasbrain::channels
package require dasbrain::chanopt

package provide dasbrain::slowvoice 1.0

namespace eval ::dasbrain::slowvoice {
	::dasbrain::channels::on-event join ::dasbrain::slowvoice::JOIN
	::dasbrain::channels::on-event djoin ::dasbrain::slowvoice::JOIN
	::dasbrain::channels::on-event preremove ::dasbrain::slowvoice::PREREMOVE
	
	copt register auto-voice int 0
	copt register auto-voice-registered flag 0
}

proc ::dasbrain::slowvoice::JOIN {chan userrec} {
	set nick [dict get $userrec nick]
	set net [::hexchat::getinfo network]
	if {[copt get $net $chan auto-voice-registered] &&
		[dict exists $userrec account] && [dict get $userrec account] ne {*}} {
		addtimer 100 $chan $nick
		return
	}
	set avoicetime [copt get $net $chan auto-voice]
	if {$avoicetime > 0} {
		if {[dict exists $userrec jointime]} {
			set in [expr {([dict get $userrec jointime] + $avoicetime - [clock seconds]) * 1000}]
			if {$in <= 0} {
				set in 100
			}
			addtimer $in $chan $nick
		}
	}
}

proc ::dasbrain::slowvoice::addtimer {when chan nick} {
	set sid [::hexchat::prefs id]
	dict set ::dasbrain::channels::channels $sid $chan users $nick voicetimer [::hexchat::hook_timer $when [list ::dasbrain::slowvoice::give-voice $sid $chan $nick]]
}

proc ::dasbrain::slowvoice::give-voice {sid chan nick} {
	if {![dict exists $::dasbrain::channels::channels $sid $chan users $nick]} {return 0}
	dict unset ::dasbrain::channels::channels $sid $chan users $nick voicetimer
	set userrec [dict get $::dasbrain::channels::channels $sid $chan users $nick]
	
	if {[dict exists $userrec prefix] && [dict size [dict get $userrec prefix]] > 0} {return 0}
	
	set cfields [::hexchat::list_fields channels]
	set ctxidx [lsearch $cfields context]
	set ididx [lsearch $cfields id]
	
	foreach cinfo [::hexchat::getlist channels] {
		if {[lindex $cinfo $ididx] == $sid} {
			::hexchat::setcontext [lindex $cinfo $ctxidx]
			::dasbrain::modequeue::pushmode $chan +v $nick
			break
		}
	}
	return 0
}

proc ::dasbrain::slowvoice::PREREMOVE {chan userrec args} {
	if {[dict exists $userrec voicetimer]} {
		::hexchat::unregister_hook [dict get $userrec voicetimer]
	}
}