extends RefCounted

const EVIDENCE := {
	"evidence_past": ["l3_authorization", "Project Continuity / Authorization", "AUTHORIZATION: Project Continuity / Manual Override Approved - Professor A. Vale.\n\nThe Professor knowingly enabled the forbidden experiment to keep his timeline from disappearing.\n\nRestricted failsafe: CLAIM ORIGIN redirects the anchor to the younger identity. Its signature matches the protocol that caused the First Fracture."],
	"warning": ["l3_warning", "A warning in your handwriting", "IF HE TELLS YOU THE CORE IS SAFE, ASK WHAT HAPPENS TO HIM WHEN IT STOPS.\n\nThe safe protocol grounds the core and preserves the Student. The current Professor and his memories dissolve.\n\nStudent: You knew what this machine would do?"],
	"evidence_future": ["l3_continuity", "Continuity recording / recovered", "Echo continuity will be terminated if the core is grounded.\n\nYou are an anchored temporal echo outside linear causality. Rewriting the past will not erase you while you hold the anchor.\n\nRELEASE THE ECHO saves the world and the younger self, but ends your current existence. PRESERVE ECHO seizes the anchor and erases the Student.\n\nProfessor: I was afraid there would be nothing left of me."],
	"routing": ["l3_routing", "Damaged routing diagram", "RECEIVER BATTERY / Restore it before trusting the surviving readings.\n\nPOWER COILS, WEST BANK:\nCOIL 1 = 2    /    COIL 2 = 0    /    COIL 3 = 1\nEach relay cycles 0 -> 1 -> 2 -> 0. Incorrect settings can be changed.\n\nPower rebuilds the collapsed north conduit. Calibrate the Signal Anchor beyond it to expose the Origin waveform in the Past. Both phase switches must then be used within five seconds."]
}

const ENDINGS := {
	"trust": {"title": "THE LAST GOODBYE", "lines": ["Professor: You made a different choice than I did.", "Student: I won't forget that you helped me make it.", "The rift seals. The Professor releases his echo and its memories. The Student and the world survive."], "color": Color("8ee5bb"), "erased": "future"},
	"student_override": {"title": "ERASED FUTURE", "lines": ["ORIGIN CLAIM ACCEPTED / FORBIDDEN PROTOCOL SIGNATURE MATCH", "Student: This is the same command you used.", "The younger identity takes the anchor by force. The Professor and his timeline are erased. The Student survives with proof of what he has done."], "color": Color("efb851"), "erased": "future"},
	"professor_override": {"title": "STOLEN TOMORROW", "lines": ["ECHO PRESERVATION ACCEPTED / ORIGINAL IDENTITY DISPLACED", "Professor: I thought surviving would feel different.", "The anchored echo endures outside the rewritten past. The Student disappears. A changed, silent future remains."], "color": Color("84a8ee"), "erased": "past"},
	"paradox": {"title": "ITERATION 02", "lines": ["CONFLICTING IDENTITY CLAIMS / ANCHOR COLLAPSE", "Student: Hello? Is someone there?", "The first-contact signal returns. ITERATION 02 DETECTED."], "color": Color("b584e8"), "erased": "both"}
}
