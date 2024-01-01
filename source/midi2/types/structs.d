module midi2.types.structs;

/**
 * midi2 - MIDI 2.0 implementation.
 *
 * midi2.types.structs:
 *
 * Contains Universal MIDI Packets, etc.
 */

public import midi2.types.enums;

/**
 * Defines a basic Universal MIDI Packet.
 * 
 * Extra data (64 bit and larger) are stored in separate fields.
 *
 * Original format is in little endian, and the current implementation is formed around that. If you
 * need big endian support for some MCU, then you can implement it. :)
 */
struct UMP {
	union {
		uint		base;	///Value of the UMP as a single unsigned 32 bit integer
		ubyte[4]	bytes;	///Individual bytes of the UMP's field
	}
	@nogc @safe nothrow pure {
		/**
		 * Creates a UMP with two 8 bit fields.
		 */
		this(ubyte msgType, ubyte group, ubyte status, ubyte channel, ubyte val0 = 0, ubyte val1 = 0) {
			bytes[3] = cast(ubyte)((msgType<<4) | (group & 0xF));
			bytes[2] = cast(ubyte)((status<<4) | (channel & 0xF));
			bytes[1] = val0;
			bytes[0] = val1;
		}
		/**
		 * Creates a MIDI 1.0 compatible pitch-bend command.
		 */
		this(ubyte group, ubyte channel, ushort val) {
			bytes[3] = (MessageType.MIDI1<<4) | (group & 0xF);
			bytes[2] = (MIDI1_0Cmd.PitchBend<<4) | (channel & 0xF);
			bytes[1] = cast(ubyte)((val>>7)&0x7F);
			bytes[0] = cast(ubyte)(val&0x7F);
		}
		///Creates a UMP from a 32 bit integer.
		this(uint base) {
			this.base = base;
		}
		///Creates a UMP from 4 separate bytes, keeping the correct endian order.
		this(ubyte[4] bytes) {
			this.bytes[0] = bytes[3];
			this.bytes[1] = bytes[2];
			this.bytes[2] = bytes[1];
			this.bytes[3] = bytes[0];
		}
		/**
		 * Returns the message type of the packet.
		 *
		 * This value should not be changed on the fly.
		 */
		ubyte msgType() const {
			return bytes[3]>>4;
		}
		/**
		 * Returns the group of the packet. 
		 */
		ubyte group() const {
			return bytes[3] & 0xF;
		}
		/**
		 * Sets the group of the packet.
		 */
		ubyte group(ubyte val) {
			bytes[3] &= 0xF0;
			bytes[3] |= val & 0xF;
			return bytes[3] & 0xF;
		}
		/**
		 * Returns the status value of the field, or 0 if message type hasn't defined it.
		 */
		ubyte status() const {
			switch (msgType) {
				case MessageType.MIDI2 , MessageType.MIDI1 , MessageType.Data64 , MessageType.Data128:
					return bytes[2]>>4;
				default:
					return bytes[2];
			}
		}
		/**
		 * Returns the note number of this packet.
		 */
		ubyte note() const {
			return bytes[1];
		}
		/**
		 * Sets the note number of this packet.
		 */
		ubyte note(ubyte val) {
			return bytes[1] = val;
		}
		alias index = note;
		alias program = note;
		/**
		 * Returns the value of this packet.
		 */
		ubyte value() const {
			return bytes[0];
		}
		/**
		 * Sets the value of this packet.
		 */
		ubyte value(ubyte val) {
			return bytes[0] = val;
		}
		alias velocity = value;
		/**
		 * Returns the pitch bend value of this packet.
		 */
		ushort bend() const {
			return (cast(ushort)bytes[0])<<7 | bytes[1];
		}
		/**
		 * Return the channel number of this packet.
		 */
		ubyte channel() const {
			return bytes[2] & 0xF;
		}
		/**
		 * Sets the channel number of this packet.
		 */
		ubyte channel(ubyte val) {
			bytes[2] &= 0xF0;
			bytes[2] |= val & 0xF;
			return bytes[2] & 0xF;
		}
		T opCast(T)() const {
			static if (is(T == uint)) {
				return base;
			}
		}
	}
}
/**
 * Defines the MIDI 2.0 note commands' data fields.
 */
struct NoteVals {
	ushort		attrData;	///Attribute data
	ushort		velocity;	///Velocity of the note
}


unittest {
	assert(UMP.sizeof == 4);
	assert(NoteVals.sizeof == 4);
	
	UMP a = UMP(MessageType.MIDI2, 0x5, MIDI2_0Cmd.NoteOn, 0x3, 0x84, 0x35);
	assert(a.msgType == MessageType.MIDI2);
	assert(a.group == 0x5);
	assert(a.status == MIDI2_0Cmd.NoteOn);
	assert(a.channel == 0x3);
	assert(a.note == 0x84);
	assert(a.value == 0x35);
}