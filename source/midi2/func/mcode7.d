module midi2.func.mcode7;

/**
 * midi2 - MIDI 2.0 implementation.
 *
 * midi2.func.mcode7:
 *
 * Implements Mcoded7 algorithms
 *
 * This algorithm is used for MIDI CI, but also can be used to encode things like binary data streams sent through
 * MIDI SysEx commands.
 */

/**
 * Mcoded7 coder status return codes.
 */
enum MCoded7Status {
	AllInputConsumed,
	NeedsMoreOutput,
	AlreadyFinalized,
	Finished,
}
/**
 * Mcoded7 encoder.
 *
 * Uses either a classical length-pointer pair for nogc targets, or D's own dynamic arrays for gc targets.
 */
struct MCoded7Encoder {
	size_t		counter;	///The amount of encoded data.
	ubyte[8]	currOut;	///The currently outputted data.
	ubyte[7]	currIn;		///The currently inputted data.
	ubyte		flags;		///Status flags. Bit 7 is set if finalization is complete, bit 6 is set if there's remainder data, bits 0-2 indicate remainder of the currently outputted chunk.
	version (midi2_nogc) {
		size_t			inSize;	///The remaining data in the input stream
		const(ubyte)*	input;	///The pointer to the current byte in the input stream
		size_t			outSize;///The remaining data in the output stream
		ubyte*			output;	///The pointer to the current first byte in the output stream
	} else {
		const(ubyte)[]	input;	///The input stream
		ubyte[]			output;	///The output stream
	}
	@nogc @safe pure nothrow {
		version (midi2_nogc) {
			/**
			 * Creates an encoder with the supplied starting streams
			 */
			this(size_t inSize, const(ubyte)* input, size_t outSize, ubyte output) {
				this.inSize = inSize;
				this.input = input;
				this.outSize = outSize;
				this.output = output;
			}
			/**
			 * Encodes all possible data on the input stream without needing to pad out the end
			 */
			MCoded7Status encode() {
				if (flags & 0x07) {
					for (int i = flags & 0x07 ; i < 8 ; i++) {
						if (!outSize) {
							flags = cast(ubyte)(flags & 0xB0 | i);
							return MCoded7Status.NeedsMoreOutput;
						}
						*output = currOut[i];
						outSize--;
						output++;
					}
				}
				if (!flags & 0x80) {
					while (inSize) {
						if (fillInputChunk) {
							flags |= 0x40;
							return MCoded7Status.AllInputConsumed;
						}
						encodeChunk;
						for (int i ; i < 8 ; i++) {
							if (!outSize) {
								flags = cast(ubyte)(flags & 0xB0 | i);
								return MCoded7Status.NeedsMoreOutput;
							}
							*output = currOut[i];
							outSize--;
							output++;
						}
					}
				} else return MCoded7Status.AlreadyFinalized;
			}
			/**
			 * Finalizes the stream once no more output is needed to be put onto the stream.
			 * Consumes the remaining data on the input if any, then pads the end if needed.
			 */
			MCoded7Status finalize() {
				if (!flags & 0x80) return MCoded7Status.AlreadyFinalized;
				MCoded7Status state = encode();
				if (state == MCoded7Status.NeedsMoreOutput)
					return state;
				if (flags & 0x40) {
					for (int i = flags & 0x07 ; i < 8 ; i++) {
						if (!outSize) {
							flags = cast(ubyte)(flags & 0xB0 | i);
							return MCoded7Status.NeedsMoreOutput;
						}
						*output = currOut[i];
						outSize--;
						output++;
					}
				}
				return MCoded7Status.Finished;
			}
			/**
			 * Fills the current input chunk from the input stream and raises the counter by the amount.
			 * Returns 0 if the 
			 */
			protected size_t fillInputChunk() {
				do {
					if (!inSize) return counter % 7;
					currIn[counter % 7] = *input;
					inSize--;
					input++;
					counter++;
				} while (counter % 7);
				return 0;
			}
		} else {
			/**
			 * Creates an encoder with the supplied starting streams
			 */
			this(const(ubyte)[] input, ubyte[] output) {
				this.input = input;
				this.output = output;
			}
		}
		/**
		 * Encodes the current chunk.
		 */
		protected void encodeChunk() {
			for (int i ; i < 7 ; i++) {
				currOut[i + 1] = currIn[i] & 0x7F;
				currOut[0] |= (currIn[i] & 0x80)>>(i + 1);
			}
		}
	}
	
}