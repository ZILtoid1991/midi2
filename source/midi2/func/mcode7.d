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
	size_t		outCount;	///The amount of outputted data.
	ubyte[8]	currOut;	///The currently outputted data.
	ubyte[7]	currIn;		///The currently inputted data.
	ubyte		flags;		///Status flags. Bit 7 is set if finalization is complete
	version (midi2_nogc) {
		size_t			inSize;	///The remaining data in the input stream
		const(ubyte)*	input;	///The pointer to the current byte in the input stream
		size_t			outSize;///The remaining data in the output stream
		ubyte*			output;	///The pointer to the current first byte in the output stream
	} else {
		const(ubyte)[]	input;	///The input stream
		ubyte[]			output;	///The output stream
		size_t			inPos;	///Input position
		size_t			outPos;	///Output position
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
			MCoded7Status encode() @trusted {
				if (outCount % 8) {		//empty output if needed
					if (emptyOutputChunk())
						return MCoded7Status.NeedsMoreOutput;
				}
				if (!flags & 0x80) {
					while (inSize) {
						if (fillInputChunk())
							return MCoded7Status.AllInputConsumed;
						encodeChunk();
						if (emptyOutputChunk())
							return MCoded7Status.NeedsMoreOutput;
					}
					return MCoded7Status.AllInputConsumed;
				} else return MCoded7Status.AlreadyFinalized;
			}
			/**
			 * Finalizes the stream once no more output is needed to be put onto the stream.
			 * Consumes the remaining data on the input if any, then pads the end if needed.
			 */
			MCoded7Status finalize() @trusted {
				if (!flags & 0x80) return MCoded7Status.AlreadyFinalized;
				MCoded7Status state = encode();
				if (state == MCoded7Status.NeedsMoreOutput)
					return state;
				encodeChunk();
				if (emptyOutputChunk())
					return MCoded7Status.NeedsMoreOutput;
				flags |= 0x80;
				return MCoded7Status.Finished;
			}
			/**
			 * Fills the current input chunk from the input stream and raises the counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-6 if the input chunk isn't complete.
			 */
			protected size_t fillInputChunk() @system {
				do {
					if (!inSize) return counter % 7;
					currIn[counter % 7] = *input;
					inSize--;
					input++;
					counter++;
				} while (counter % 7);
				return 0;
			}
			/**
			 * Empties the current output chunk to the output stream, and raises the output counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-7 if the chunk isn't complete.
			 */
			protected size_t emptyOutputChunk() @system {
				do {
					if (!outSize) return outCount % 8;
					*output = currOut[outCount % 8];
					currOut[outCount % 8] = 0;
					outSize--;
					output++;
					outCount++;
				} while (outCount % 8);
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
	version (midis_nogc) {

	} else {
		@safe pure nothrow {
			/**
			 * Fills the current input chunk from the input stream and raises the counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-6 if the input chunk isn't complete.
			 */
			protected size_t fillInputChunk() {
				do {
					if (input.length == inPos) return counter % 7;
					currIn[counter % 7] = input[inPos];
					inPos++;
					counter++;
				} while (counter % 7);
				return 0;
			}
			/**
			 * Empties the current output chunk to the output stream, and raises the output counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-7 if the chunk isn't complete.
			 */
			protected size_t emptyOutputChunk() {
				do {
					if (output.length == outPos) return outCount % 8;
					output[outPos] = currOut[outCount % 8];
					outPos++;
					outCount++;
				} while (outCount % 8);
				return 0;
			}
			/**
			 * Encodes all possible data on the input stream without needing to pad out the end
			 */
			MCoded7Status encode() {
				if (outCount % 8) {		//empty output if needed
					if (emptyOutputChunk())
						return MCoded7Status.NeedsMoreOutput;
				}
				if (!flags & 0x80) {
					while (input.length != inPos) {
						if (fillInputChunk())
							return MCoded7Status.AllInputConsumed;
						encodeChunk();
						if (emptyOutputChunk())
							return MCoded7Status.NeedsMoreOutput;
					}
					return MCoded7Status.AllInputConsumed;
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
				encodeChunk();
				if (emptyOutputChunk())
					return MCoded7Status.NeedsMoreOutput;
				flags |= 0x80;
				return MCoded7Status.Finished;
			}
		}
	}
}
/**
 * Mcoded7 decode.
 *
 * Uses either a classical length-pointer pair for nogc targets, or D's own dynamic arrays for gc targets.
 */
struct MCoded7Decoder {
	size_t		counter;	///The amount of encoded data.
	size_t		outCount;	///The amount of outputted data.
	ubyte[8]	currIn;	///The currently outputted data.
	ubyte[7]	currOut;		///The currently inputted data.
	ubyte		flags;		///Status flags. Bit 7 is set if finalization is complete
	version (midi2_nogc) {
		size_t			inSize;	///The remaining data in the input stream
		const(ubyte)*	input;	///The pointer to the current byte in the input stream
		size_t			outSize;///The remaining data in the output stream
		ubyte*			output;	///The pointer to the current first byte in the output stream
	} else {
		const(ubyte)[]	input;	///The input stream
		ubyte[]			output;	///The output stream
		size_t			inPos;	///Input position
		size_t			outPos;	///Output position
	}
}