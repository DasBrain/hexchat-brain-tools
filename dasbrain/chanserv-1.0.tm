package require hexchat
package require dasbrain::invitejoin
package require dasbrain::chanopt
package require dasbrain::need

package provide dasbrain::chanserv 1.0

namespace eval ::dasbrain::chanserv {
	::dasbrain::chanopt::register cs-invite flag 0
	::dasbrain::chanopt::register cs-unban flag 0
	::dasbrain::chanopt::register cs-voice flag 0
	::dasbrain::chanopt::register cs-hop flag 0
	::dasbrain::chanopt::register cs-op flag 0
	::dasbrain::chanopt::register cs-admin flag 0
	::dasbrain::chanopt::register cs-owner flag 0
	
	::dasbrain::need::handler ::dasbrain::chanserv::need
}

proc ::dasbrain::chanserv::need {what channel} {
	if {$what eq {key}} {
		set what invite
	}
	if {[copt get [::hexchat::getinfo network] $channel cs-$what]} {
		::hexchat::command "RAW CS $what $channel"
		if {$what eq {invite}} {
			::dasbrain::invitejoin::addjoin $channel
		} elseif {$what in {admin owner}} {
			if {[copt get [::hexchat::getinfo network] $channel cs-op]} {
				::hexchat::command "RAW CS OP $channel"
			}
		}
	}
}