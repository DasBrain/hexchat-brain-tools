package require hexchat
package require dasbrain::isupport
package require dasbrain::modeparse
package require dasbrain::chanopt

package provide dasbrain::channels 1.0

namespace eval ::dasbrain::channels {
	namespace import ::dasbrain::isupport::ircsplit ::dasbrain::isupport::isupport
	if {![info exists channels]} {
		variable channels [dict create]
	}
	if {![info exists events]} {
		variable events [dict create]
	}
	if {![info exists auth-provider]} {
		variable auth-provider {}
	}
	if {![info exists join_hook]} {
		variable join_hook [::hexchat::hook_server JOIN ::dasbrain::channels::JOIN]
	}
	if {![info exists part_hook]} {
		variable part_hook [::hexchat::hook_server PART ::dasbrain::channels::PART]
	}
	if {![info exists quit_hook]} {
		variable quit_hook [::hexchat::hook_server QUIT ::dasbrain::channels::QUIT]
	}
	if {![info exists kick_hook]} {
		variable kick_hook [::hexchat::hook_server KICK ::dasbrain::channels::KICK]
	}
	if {![info exists nick_hook]} {
		variable nick_hook [::hexchat::hook_server NICK ::dasbrain::channels::NICK]
	}
	if {![info exists 354_hook]} {
		variable 354_hook [::hexchat::hook_server 354 ::dasbrain::channels::354]
	}
	if {![info exists 352_hook]} {
		variable 352_hook [::hexchat::hook_server 352 ::dasbrain::channels::352]
	}
	if {![info exists 353_hook]} {
		variable 353_hook [::hexchat::hook_server 353 ::dasbrain::channels::353]
	}
	if {![info exists 315_hook]} {
		variable 315_hook [::hexchat::hook_server 315 ::dasbrain::channels::315]
	}
	if {![info exists ACCOUNT_hook]} {
		variable ACCOUNT_hook [::hexchat::hook_server ACCOUNT ::dasbrain::channels::ACCOUNT]
	}
	if {![info exists AWAY_hook]} {
		variable AWAY_hook [::hexchat::hook_server AWAY ::dasbrain::channels::AWAY]
	}
	if {![info exists CHGHOST_hook]} {
		variable CHGHOST_hook [::hexchat::hook_server CHGHOST ::dasbrain::channels::CHGHOST]
	}
	if {![info exists Disconnected_hook]} {
		variable Disconnected_hook [::hexchat::hook_print Disconnected ::dasbrain::channels::Disconnected]
	}
	if {![info exists 324_hook]} {
		variable 324_hook [::hexchat::hook_server 324 ::dasbrain::channels::324]
	}
	if {![info exists djoin_timer]} {
		variable djoin_timer [::hexchat::hook_timer 60000 ::dasbrain::channels::djoincheck]
	}
	nopt register account-host-regexp string {}
	::dasbrain::modeparse::handler ::dasbrain::channels::mode-change
	namespace export on-event userrec userlist chanmodes meop seturec
}

proc ::dasbrain::channels::on-event {event cmd} {
	variable events
	if {![dict exists $events $event] || $cmd ni [dict get $events $event]} {
		dict lappend events $event $cmd
	}
}

proc ::dasbrain::channels::emit-event {event args} {
	variable events
	if {![dict exists $events $event]} {return}
	foreach h [dict get $events $event] {
		try {
			{*}$h {*}$args
		} on error {- opt} {
			::hexchat::print "$event $h $args\t[dict get $opt -errorinfo]"
		}
	}
}


proc ::dasbrain::channels::nuh2nick {nuh} {
	set bangidx [string first ! $nuh]
	if {$bangidx != -1} {
		return [string range $nuh 0 $bangidx-1]
	} else {
		return $nuh
	}
}

proc ::dasbrain::channels::do-auth {chan userrec} {
	variable auth-provider
	if {${auth-provider} eq {}} {
		set handle *
		set caps [list]
	} else {
		lassign [{*}${auth-provider} $chan $userrec] handle caps
	}
	variable channels
	set sid [::hexchat::prefs id]
	dict set channels $sid $chan users [dict get $userrec nick] handle $handle
	dict set channels $sid $chan users [dict get $userrec nick] caps $caps
	if {![dict exists $userrec handle] || [dict get $userrec handle] ne $handle} {
		emit-event chghandle $chan [dict get $channels $sid $chan users [dict get $userrec nick]]
	}
}


proc ::dasbrain::channels::JOIN {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set sid [::hexchat::prefs id]
	set chan [lindex $line 2]
	set from [lindex $line 0]
	set userrec [dict create gotjoin 1]
	set bangidx [string first ! $from]
	if {$bangidx != -1} {
		set nick [string range $from 0 $bangidx-1]
		dict set userrec uhost [string range $from $bangidx+1 end]
	} else {
		set nick $from
	}
	dict set userrec nick $nick
	if {[llength $line] >= 5} {
		# extended join
		dict set userrec account [lindex $line 3]
		dict set userrec realname [lindex $line end]
	} else {
		set acchost [cnopt get account-host-regexp]
		if {$acchost ne {} && [regexp $acchost [dict get $userrec uhost] - account]} {
			dict set userrec account $account
		}
	}
	variable channels
	dict for {k v} $userrec {
		dict set channels $sid $chan users $nick $k $v
	}
	dict for {k v} [dict create prefix [dict create] flags [dict create H 1] jointime [clock seconds]] {
		if {![dict exists $channels $sid $chan users $nick $k]} {
			dict set channels $sid $chan users $nick $k $v
		}
	}
	# Remove delay-join flag if it exists
	dict unset channels $sid $chan users $nick flags <
	do-auth $chan [dict get $channels $sid $chan users $nick]
	emit-event join $chan $userrec
	if {[llength $line] >= 5 && ![dict exists $channels $sid $chan users $nick djoin-done]} {
		emit-event djoin $chan $userrec
		dict set channels $sid $chan users $nick djoin-done 1
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::remuser {chan nick how reason src} {
	variable channels
	set sid [::hexchat::prefs id]
	set userrec [dict get $channels $sid $chan users $nick]
	emit-event preremove $chan $userrec $how $reason $src
	if {[::hexchat::nickcmp $nick [::hexchat::getinfo nick]] == 0} {
		# We leave.
		dict unset channels $sid $chan
	} else {
		dict unset channels $sid $chan users $nick
	}
	emit-event postremove $chan $userrec $how $reason $src
}

proc ::dasbrain::channels::PART {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set nick [nuh2nick [lindex $line 0]]
	remuser [lindex $line 2] $nick PART [lindex $line 3] [lindex $line 0]
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::QUIT {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set nick [nuh2nick [lindex $line 0]]
	variable channels
	dict for {chan info} [dict get $channels [::hexchat::prefs id]] {
		if {[dict exists $info users $nick]} {
			remuser $chan $nick QUIT [lindex $line 2] [lindex $line 0]
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::KICK {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set reason {}
	lassign $line src - chan target reason
	remuser $chan $target KICK $reason $src
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::NICK {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set nick [nuh2nick [lindex $line 0]]
	set newnick [lindex $line 2]
	variable channels
	set sid [::hexchat::prefs id]
	if {![dict exists $channels $sid]} {return}
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			dict set channels $sid $chan users $newnick [dict get $info users $nick]
			dict unset channels $sid $chan users $nick
			dict set channels $sid $chan users $newnick nick $newnick
		}
	}
	return $::hexchat::EAT_NONE
}

#<< WHO #eggdrop %chtsunfra,152
#>> :adrift.sg.quakenet.org 354 DasBrain 152 #eggdrop TheQBot CServe.quakenet.org *.quakenet.org Q H*@d Q :The Q Bot
proc ::dasbrain::channels::354 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	switch -exact -- [lindex $line 3] {
		152 {
			# Hexchat query
			lassign $line - - - - chan user host server nick flags account realname
			variable channels
			set sid [::hexchat::prefs id]
			if {$account eq {0}} {
				set account *
			}
			if {![dict exists $channels $sid $chan users $nick]} {
				dict set channels $sid $chan users $nick jointime [clock seconds]
			}
			set oldinfo [dict get $channels $sid $chan users $nick]
			dict set channels $sid $chan users $nick uhost ${user}@${host}
			dict set channels $sid $chan users $nick realname $realname
			dict set channels $sid $chan users $nick account $account
			dict set channels $sid $chan users $nick server $server
			dict set channels $sid $chan users $nick nick $nick
			set nflags [dict create]
			foreach c [split $flags {}] {
				dict set nflags $c 1
				if {$c eq {+}} {
					# Special case + (voice), as quakenet/undernet doesn't have multi-prefix.
					dict set channels $sid $chan users $nick prefix + 1
				}
			}
			dict set channels $sid $chan users $nick flags $nflags
			if {![dict exists $oldinfo account] || [dict get $oldinfo account] ne $account ||
				![dict exists $oldinfo uhost] || [dict get $oldinfo uhost] ne "${user}@${host}"} {
				do-auth $chan [dict get $channels $sid $chan users $nick]
			}
			if {![dict exists $channels $sid $chan users $nick djoin-done]} {
				emit-event djoin $chan [dict get $channels $sid $chan users $nick]
				dict set channels $sid $chan users $nick djoin-done 1
			}
			return $::hexchat::EAT_NONE
		}
		313 {
			# see through delay-join query
			lassign $line - - - - chan user host server nick flags account realname
			variable channels
			set sid [::hexchat::prefs id]
			
			if {![dict exists $channels $sid $chan wholist]} {
				dict set channels $sid $chan wholist [dict create]
				if {[dict exists $channels $sid $chan users]} {
					dict for {k v} [dict get $channels $sid $chan users] {
						dict set channels $sid $chan wholist $k 1
					}
				}
			}
			dict unset channels $sid $chan wholist $nick
			
			if {$account eq {0}} {
				set account *
			}
			set nflags [dict create]
			if {![dict exists $channels $sid $chan users $nick]} {
				dict set channels $sid $chan users $nick jointime [clock seconds]
				dict set nflags < 1
			}
			set oldinfo [dict get $channels $sid $chan users $nick]
			dict set channels $sid $chan users $nick uhost ${user}@${host}
			dict set channels $sid $chan users $nick realname $realname
			dict set channels $sid $chan users $nick account $account
			dict set channels $sid $chan users $nick server $server
			dict set channels $sid $chan users $nick nick $nick

			foreach c [split $flags {}] {
				dict set nflags $c 1
				if {$c eq {+}} {
					# Special case + (voice), as quakenet/undernet doesn't have multi-prefix.
					dict set channels $sid $chan users $nick prefix + 1
				}
			}
			dict set channels $sid $chan users $nick flags $nflags
			if {![dict exists $oldinfo account] || [dict get $oldinfo account] ne $account ||
				![dict exists $oldinfo uhost] || [dict get $oldinfo uhost] ne "${user}@${host}"} {
				do-auth $chan [dict get $channels $sid $chan users $nick]
			}
			if {![dict exists $channels $sid $chan users $nick djoin-done]} {
				emit-event djoin $chan [dict get $channels $sid $chan users $nick]
				dict set channels $sid $chan users $nick djoin-done 1
			}
			return $::hexchat::EAT_HEXCHAT
		}
	}
	return $::hexchat::EAT_NONE
}

# >> :cymru.us.quakenet.org 315 DasBrain #giveaway :End of /WHO list.
proc ::dasbrain::channels::315 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set chan [lindex $line 3]
	set sid [::hexchat::prefs id]
	variable channels
	if {[dict exists $channels $sid $chan wholist]} {
		dict for {k -} [dict get $channels $sid $chan wholist] {
			if {![dict exists $channels $sid $chan users $k flags <]} {
				::hexchat::print "WARNING\tUser left ${chan}? [list [dict get $channels $sid $chan users $k]]"
			}
			remuser $chan $k DJOIN-LEFT {} {}
		}
		dict unset channels $sid $chan wholist
		emit-event dcheck $chan
		return $::hexchat::EAT_HEXCHAT
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::djoincheck {} {
	variable channels
	
	set cfields [::hexchat::list_fields channels]
	set ctxidx [lsearch $cfields context]
	set ididx [lsearch $cfields id]
	
	set origctx [::hexchat::getcontext]
	
	dict for {sid chans} $channels {
		dict for {chan cdict} $chans {
			if {[dict exists $cdict mode D] || [dict exists $cdict mode d]} {
				foreach cinfo [::hexchat::getlist channels] {
					if {[lindex $cinfo $ididx] == $sid} {
						::hexchat::setcontext [lindex $cinfo $ctxidx]
						::hexchat::command "QUOTE WHO $chan d%chtsunfra,313"
						break
					}
				}
			}
		}
	}
	::hexchat::setcontext $origctx
	return 1
}

#<< WHO #YATC
#>> :irc.lim.de.euirc.net 352 DasBrain #YATC ~DasBrain DasBrain.euirc.net irc.lim.de.euirc.net DasBrain H@ :0 DasBrain
proc ::dasbrain::channels::352 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign $line - - - chan user host server nick flags realname
	# Realname contains hops. Who (pun not intendet) got that idea?
	set rnspace [string first { } $realname]
	if {$rnspace != -1 && [string is integer -strict [string range $realname 0 $rnspace-1]]} {
		set realname [string range $realname $rnspace+1 end]
	}
	variable channels
	set sid [::hexchat::prefs id]
	dict set channels $sid $chan users $nick uhost ${user}@${host}
	dict set channels $sid $chan users $nick realname $realname
	dict set channels $sid $chan users $nick server $server
	dict set channels $sid $chan users $nick nick $nick
	set nflags [dict create]
	foreach c [split $flags {}] {
		dict set nflags $c 1
		if {$c eq {+}} {
			# Special case + (voice), as quakenet/undernet doesn't have multi-prefix.
			dict set channels $sid $chan users $nick prefix + 1
		}
	}
	dict set channels $sid $chan users $nick flags $nflags
	if {![dict exists $channels $sid $chan users $nick djoin-done]} {
		emit-event djoin $chan [dict get $channels $sid $chan users $nick]
		dict set channels $sid $chan users $nick djoin-done 1
	}
	return $::hexchat::EAT_NONE
}

#>> :tungsten.libera.chat 353 DasBrain = ###test :DasBrain karthik BOFH @ChanServ
proc ::dasbrain::channels::353 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign $line - - - - chan users
	variable channels
	set sid [::hexchat::prefs id]
	set prefixes [isupport get PREFIX]
	set prefixes [split [string range $prefixes [string first ) $prefixes]+1 end] {}]
	foreach u [split $users] {
		set userrec [dict create gotjoin 1]
		set bangidx [string first ! $u]
		if {$bangidx != -1} {
			# we have userhost-in-names
			dict set userrec uhost [string range $u $bangidx+1 end]
			set u [string range $u 0 $bangidx-1]
		}
		while {[string index $u 0] in $prefixes} {
			dict set userrec prefix [string index $u 0] 1
			set u [string range $u 1 end]
		}
		dict set userrec nick $u
		dict for {k v} $userrec {
			dict set channels $sid $chan users $u $k $v
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::ACCOUNT {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign line from - account
	set nick [nuh2nick $from]
	variable channels
	set sid [::hexchat::prefs id]
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			dict set channels $sid $chan users $nick account $account
			emit-event userchg $chan [dict get $channels $sid $chan users $nick]
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::AWAY {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	if {[llength $line] == 2} {
		set away 0
	} else {
		set away 1
		set away-reason [lindex $line 2]
	}
	set nick [nuh2nick [lindex $line 0]]
	variable channels
	set sid [::hexchat::prefs id]
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			if {$away} {
				dict unset channels $sid $chan users $nick flags H
				dict set channels $sid $chan users $nick flags G 1
				dict set channels $sid $chan users $nick away-reason ${away-reason}
			} else {
				dict unset channels $sid $chan users $nick flags G
				dict set channels $sid $chan users $nick flags H 1
				dict unset channels $sid $chan users $nick away-reason
			}
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::CHGHOST {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign line from - user host
	set nick [nuh2nick $from]
	set newuhost ${user}@${host}
	variable channels
	set sid [::hexchat::prefs id]
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			dict set channels $sid $chan users $nick uhost $newuhost
			emit-event userchg $chan [dict get $channels $sid $chan users $nick]
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::Disconnected {word} {
	variable channels
	dict unset channels [::hexchat::prefs id]
	return ::hexchat::EAT_NONE
}

#>> :tulip.eu.ix.undernet.org 324 DasBrain #computertech +mtnRl 33
proc ::dasbrain::channels::324 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set args [lassign $line - - - chan mode]
	set chanmodes [split [isupport get CHANMODES] ,]
	foreach cms $chanmodes type {A B C D} {
		set $type [split $cms {}]
	}
	set pm +
	set chanmodes [dict create]
	foreach mc [split $mode {}] {
		if {$mc in {+ -}} {
			set pm $mc
		} elseif {$mc in $A} {
			::hexchat::print "channels\tWarning: List-Mode $mc in 324 numeric, ignoring"
		} elseif {$mc in $B || $mc in $C} {
			set args [lassign $args param]
			dict set chanmodes $mc $param
		} elseif {$mc in $D} {
			dict set chanmodes $mc 1
		} else {
			::hexchat::print "channels\tWarning: Unknown mode $mc in 324 numeric, assuming no parameter"
			dict set chanmodes $mc 1
		}
	}
	if {[llength $args] > 0} {
		::hexchat::print "channels\tWarning: Non-consumed arguments [list $args] in 324 numeric, ignoring"
	}
	variable channels
	dict set channels [::hexchat::prefs id] $chan mode $chanmodes
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::mode-change {from chan mode arg type} {
	set pm [string index $mode 0]
	set mc [string index $mode 1]
	variable channels
	switch -exact -- $type {
		A {
			# We ignore list modes for now.
			return
		}
		prefix {
			set prefixmodes [isupport get PREFIX]
			set prefixpos [string first ) $prefixmodes]
			set prefixchars [split [string range $prefixmodes $prefixpos+1 end] {}]
			set prefixmodes [split [string range $prefixmodes 1 $prefixpos-1] {}]
			set pc [lindex $prefixchars [lsearch $prefixmodes $mc]]
			if {$pm eq {+}} {
				dict set channels [::hexchat::prefs id] $chan users $arg prefix $pc 1
				if {[::hexchat::nickcmp $arg [::hexchat::getinfo nick]] == 0} {
					# We got some status - yay.
					if {[lsearch $prefixmodes $mc] <= [lsearch $prefixmodes o]} {
						# We got op or higher
						emit-event gotops $chan
					}
				}
			} else {
				dict unset channels [::hexchat::prefs id] $chan users $arg prefix $pc
			}
		}
		default {
			if {$pm eq {+}} {
				dict set channels [::hexchat::prefs id] $chan mode $mc $arg
			} else {
				dict unset channels [::hexchat::prefs id] $chan mode $mc
			}
		}
	}
}

proc ::dasbrain::channels::userlist {chan} {
	variable channels
	return [dict get $channels [::hexchat::prefs id] $chan users]
}

proc ::dasbrain::channels::chanmode {chan} {
	variable channels
	return [dict get $channels [::hexchat::prefs id] $chan mode]
}

proc ::dasbrain::channels::meop {chan} {
	# TODO: Also allow modes other than +o return true?
	variable channels
	return [dict exists $channels [::hexchat::prefs id] $chan users [::hexchat::getinfo nick] prefix @]
}

proc ::dasbrain::channels::userrec {chan nick} {
	variable channels
	return [dict get $channels [::hexchat::prefs id] $chan users $nick]
}

proc ::dasbrain::channels::seturec {chan nick args} {
	variable channels
	dict set channels [::hexchat::prefs id] $chan users $nick {*}$args
}

apply {{} {
	variable channels

	set cfields [::hexchat::list_fields channels]
	set ctxidx [lsearch $cfields context]
	set chanidx [lsearch $cfields channel]
	set typeidx [lsearch $cfields type]
	set ididx [lsearch $cfields id]
	
	set ufields [::hexchat::list_fields users]
	set accidx [lsearch $ufields account]
	set awayidx [lsearch $ufields away]
	set nickidx [lsearch $ufields nick]
	set uhostidx [lsearch $ufields host]
	set prefixidx [lsearch $ufields prefix]
	set realnameidx [lsearch $ufields realname]
	
	set origctx [::hexchat::getcontext]
	
	foreach chan [::hexchat::getlist channels] {
		if {[lindex $chan $typeidx] == 2 && [lindex $chan $chanidx] ne {}} {
			::hexchat::setcontext [lindex $chan $ctxidx]
			set sid [lindex $chan $ididx]
			set channel [lindex $chan $chanidx]
			::dasbrain::channels::324 {} [list {} ":server.local 324 * $channel [::hexchat::getinfo modes]"]
			foreach u [::hexchat::getlist users] {
				set ur [dict create]
				set nick [lindex $u $nickidx]
				
				dict set ur nick $nick
				dict set ur account [lindex $u $accidx]
				if {[lindex $u $awayidx]} {
					dict set ur flags G 1
				} else {
					dict set ur flags H 1
				}
				dict set ur uhost [lindex $u $uhostidx]
				set prefix [lindex $u $prefixidx]
				if {$prefix ne {}} {
					dict set ur prefix $prefix 1
				}
				dict set ur realname [lindex $u $realnameidx]
				dict set ur gotjoin 1
				
				dict for {k v} $ur {
					if {![dict exists $channels $sid $channel users $nick $k]} {
						dict set channels $sid $channel users $nick $k $v
					}
				}
			}
		}
	}
	
	::hexchat::setcontext $origctx
} ::dasbrain::channels}