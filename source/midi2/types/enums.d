module midi2.types.enums;

/**
 * midi2 - MIDI 2.0 implementation.
 *
 * midi2.types.enums:
 *
 * Contains enumerators and other constants of various MIDI 2.0 commands, etc.
 */

/**
 * Message Type allocation.
 * 
 * The first four bits of every messabe contain the Message Type. It is used to classify message functions as well
 * as the sizes of given UMPs (see array `UMPSizes`).
 *
 * Currently only range 0x0 - 0x5 is defined. UMP sizes for those packets are included, but using them as of now
 * for custom commands might break compatibility.
 */
enum MessageType : ubyte {
	Utility		=	0x0,	///Utility messages
	SysCommMsg	=	0x1,	///System Real Time and System Common Messages (except System Exclusive)
	MIDI1		=	0x2,	///MIDI 1.0 Channel Voice Messages
	Data64		=	0x3,	///Data Messages (including System Exclusive)
	MIDI2		=	0x4,	///MIDI 2.0 Channel Voice Messages
	Data128		=	0x5,	///Data Messages
}
/**
 * MIDI 1.0 command codes.
 *
 * Mainly to provide backwards compatibility with older devices.
 */
enum MIDI1_0Cmd : ubyte {
	NoteOff		=	0x8,
	NoteOn		=	0x9,
	PolyAftrTch	=	0xA,	///Polyphonic aftertouch
	CtrlCh		=	0xB,	///Controller change
	PrgCh		=	0xC,	///Program change
	ChAftrTch	=	0xD,	///Channel aftertouch
	PitchBend	=	0xE,
	SysEx		=	0xF,	///System exclusive (not included in MIDI 2.0 specs, but added here for e.g. conversions)
}
/**
 * System Exclusive Message status values
 */
enum SysExSt : ubyte {
	Complete	=	0x0,	///Complete system exclusive message in one UMP.
	Start		=	0x1,	///Start of system exclusive message.
	Cont		=	0x2,	///Continuation of system exclusive message.
	End			=	0x3,	///End of system exclusive message.
}
/**
 * MIDI 2.0 command codes.
 */
enum MIDI2_0Cmd : ubyte {
	NoteOff		=	0x8,
	NoteOn		=	0x9,
	PolyAftrTch	=	0xA,	///Polyphonic aftertouch
	PolyCtrlChR	=	0x0,	///Per-note controller change (registered)
	PolyCtrlCh	=	0x1,	///Per-note controller change (assignable)
	NoteManaMsg	=	0xF,	///Per-note management message
	CtrlChOld	=	0xB,	///Controller change (for MIDI 1.0 compatibility)
	CtrlChR		=	0x2,	///Registered controller change with banks
	CtrlCh		=	0x3,	///Assignable controller change with banks
	RelCtrlChR	=	0x4,	///Registered, relative controller change with banks
	RelCtrlCh	=	0x5,	///Assignable, relative controller change with banks
	PrgCh		=	0xC,	///Program change
	ChAftrTch	=	0xD,	///Channel aftertouch
	PitchBend	=	0xE,	///Pitch bend (monophonic)
	PolyPitchBend=	0x6,	///Polyphonic pitch bend
}
/**
 * MIDI 2.0 note attribute types.
 */
enum MIDI2_0NoteAttrTyp : ubyte {
	None		=	0x0,
	MfgrSpec	=	0x1,	///Manufacturer specific
	ProfSpec	=	0x2,	///Profile specific
	Pitch		=	0x3,	///Pitch
}
/**
 * Utility message status codes.
 */
enum UtilityMsgSt : ubyte {
	NoOp		=	0x0,	///No operation
	JRClock		=	0x1,	///Jitter reduction clock
	JRTimestamp	=	0x2,	///Jitter reduction timestamp
}

/**
 * Contains Universal MIDI Packet (UMP) sizes in bits.
 */
immutable uint[16] umpSizes = [32,32,32,64,64,128,32,32,64,64,64,96,96,128,128,128];