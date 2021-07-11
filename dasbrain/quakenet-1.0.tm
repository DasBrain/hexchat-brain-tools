package require hexchat
package require dasbrain::invitejoin
package require dasbrain::chanopt
package require dasbrain::need

package provide dasbrain::quakenet 1.0

namespace eval ::dasbrain::quakenet {
	::dasbrain::chanopt::register q-invite flag 0
	::dasbrain::chanopt::register q-unban flag 0
	::dasbrain::chanopt::register q-voice flag 0
	::dasbrain::chanopt::register q-op flag 0
	
	::dasbrain::need::handler ::dasbrain::quakenet::need
}

proc ::dasbrain::quakenet::need {what channel} {
	if {$what eq {key}} {
		set what invite
	}
	if {[copt get [::hexchat::getinfo network] $channel q-$what] eq {1}} {
		if {$what eq {unban}} {
			set what unbanme
		}
		::hexchat::command "RAW PRIVMSG Q@CServe.quakenet.org :$what $channel"
		if {$what eq {invite}} {
			::dasbrain::invitejoin::addjoin $channel
		}
	}
}