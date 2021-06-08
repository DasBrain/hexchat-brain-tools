package require TclOO
package require hexchat

package provide matcher 1.0

namespace eval ::dasbrain::matcher {}

catch {::oo::class create ::dasbrain::matcher::base}
::oo::define ::dasbrain::matcher::base {
	method matches {matcher userrec} {
		return 0
	}
	# TODO: Add extban support
}

catch {::dasbrain::matcher::base create ::dasbrain::matcher::mask}
::oo::objdefine ::dasbrain::matcher::mask {
	method matches {matcher userrec} {
		if {![dict exists $userrec uhost]} {return 0}
		return [string match -nocase [dict get $matcher on] [dict get $userrec nick]![dict get $userrec uhost]]
	}
}

catch {::dasbrain::matcher::base create ::dasbrain::matcher::account}
::oo::objdefine ::dasbrain::matcher::account {
	method matches {matcher userrec} {
		if {![dict exists $userrec account]} {
			return 0
		}
		set have [dict get $userrec account]
		set want [dict get $matcher on]
		switch -exact -- $want {
			* {
				return [expr {$have ne {*}}]
			}
			- {
				return [expr {$have eq {*}}]
			}
			default {
				return [string equal -nocase $want $have]
			}
		}
	}
}

catch {::dasbrain::matcher::base create ::dasbrain::matcher::realname}
::oo::objdefine ::dasbrain::matcher::realname {
	method matches {matcher userrec} {
		if {![dict exists $userrec realname]} {return 0}
		return [string match -nocase [dict get $matcher on] [dict get $userrec realname]]
	}
}

# nick!user@host#realname
catch {::dasbrain::matcher::base create ::dasbrain::matcher::maskreal}
::oo::objdefine ::dasbrain::matcher::maskreal {
	method matches {matcher userrec} {
		if {![dict exists $userrec realname] || ![dict exists $userrec uhost]} {return 0}
		return [string match -nocase [dict get $matcher on] "[dict get $userrec nick]![dict get $userrec uhost]#[dict get $userrec realname]"]
	}
}

catch {::dasbrain::matcher::base create ::dasbrain::matcher::me}
::oo::objdefine ::dasbrain::matcher::me {
	method matches {matcher userrec} {
		return [expr {[dict exists $userrec nick] && [dict get $userrec nick] eq [::hexchat::getinfo nick]}]
	}
}

proc ::dasbrain::matcher::matches {matcher userrec} {
	if {![dict exists $matcher type]} {return 0}
	set obj [namespace which ::dasbrain::matcher::[dict get $matcher type]]
	if {![info object isa typeof $obj ::dasbrain::matcher::base]} {return 0}
	return [$obj matches $matcher $userrec]
}