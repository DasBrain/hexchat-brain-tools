package require hexchat

package require dasbrain::chanopt
package require dasbrain::channels

package provide dasbrain::autocycle 1.0

namespace eval ::dasbrain::autocycle {
	copt register cycle flag 0
	::dasbrain::channels::on-event postremove ::dasbrain::autocycle::POSTREMOVE
}

proc ::dasbrain::autocycle::POSTREMOVE {chan args} {
	if {[dict exists $::dasbrain::channels::channels [::hexchat::prefs id] $chan] &&
		[dict size [dict get $::dasbrain::channels::channels [::hexchat::prefs id] $chan users]] <= 1 &&
		![::dasbrain::channels::meop $chan] && 
		[ccopt get cycle]} {
		::hexchat::command "CYCLE $chan"
	}
}
