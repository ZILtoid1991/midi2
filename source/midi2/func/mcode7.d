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
 *
 * From the following input:
 * AAAAaaaa BBBBbbbb CCCCcccc DDDDdddd EEEEeeee FFFFffff GGGGgggg
 *
 * Generates the following output:
 * 0ABCDEFG 0AAAaaaa 0BBBbbbb 0CCCcccc 0DDDdddd 0EEEeeee 0FFFffff 0GGGgggg
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
	private size_t		counter;	///The amount of encoded data.
	private size_t		outCount;	///The amount of outputted data.
	private ubyte[8]	currOut;	///The currently outputted data.
	private ubyte[7]	currIn;		///The currently inputted data.
	private ubyte		flags;		///Status flags. Bit 7 is set if finalization is complete
	version (midi2_nogc) {
		private size_t			inSize;	///The remaining data in the input stream
		private const(ubyte)*	input;	///The pointer to the current byte in the input stream
		private size_t			outSize;///The remaining data in the output stream
		private ubyte*			output;	///The pointer to the current first byte in the output stream
	} else {
		private const(ubyte)[]	input;	///The input stream
		private ubyte[]			output;	///The output stream
		private size_t			inPos;	///Input position
		private size_t			outPos;	///Output position
	}
	version (midi2_nogc) {
		@nogc @safe pure nothrow {
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
				//Encode everything if it still haven't been
				const MCoded7Status state = encode();
				//At this point, the output must have enough space to accomodate an extra chunk. If not, then error 
				//out with the NeedsMoreOutput code.
				if (state == MCoded7Status.NeedsMoreOutput && outSize < 7)
					return MCoded7Status.NeedsMoreOutput;
				currOut = [0,0,0,0,0,0,0,0];
				encodeChunk();
				if (emptyOutputChunk())
					return MCoded7Status.NeedsMoreOutput;
				flags |= 0x80;
				return MCoded7Status.Finished;
			}
			/**
			 * Sets the input stream.
			 */
			void setInputStream(const(ubyte)* input, size_t inSize) {
				this.input = input;
				this.inSize = inSize;
			}
			/**
			 * Sets the output stream.
			 */
			void setOutputStream(ubyte* output, size_t outSize) {
				this.output = output;
				this.outSize = outSize;
			}
			/**
			 * Fills the current input chunk from the input stream and raises the counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-6 if the input chunk isn't complete.
			 */
			protected int fillInputChunk() @system {
				if (!inSize) return -1;
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
			protected int emptyOutputChunk() @system {
				if (!outSize) return -1;
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
		}
	} else {
		@safe pure nothrow {
			/**
			 * Creates an encoder with the supplied starting streams
			 */
			this(const(ubyte)[] input, ubyte[] output) {
				this.input = input;
				this.output = output;
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
				//Encode everything if it still haven't been
				const MCoded7Status state = encode();
				//At this point, the output must have enough space to accomodate an extra chunk. If not, then error 
				//out with the NeedsMoreOutput code.
				if (state == MCoded7Status.NeedsMoreOutput && output.length - outPos < 7)
					return MCoded7Status.NeedsMoreOutput;
				currOut = [0,0,0,0,0,0,0,0];
				encodeChunk();
				emptyOutputChunk();
				flags |= 0x80;
				return MCoded7Status.Finished;
			}
			/**
			 * Sets the input stream.
			 */
			void setInputStream(const(ubyte)[] input) {
				this.input = input;
				inPos = 0;
			}
			/**
			 * Sets the output stream.
			 */
			void setOutputStream(ubyte[] output) {
				this.output = output;
				outPos = 0;
			}
			/**
			 * Fills the current input chunk from the input stream and raises the counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-6 if the input chunk isn't complete. Returns -1 if
			 * there's no input left
			 */
			protected int fillInputChunk() {
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
			protected int emptyOutputChunk() {
				do {
					if (output.length == outPos) return outCount % 8;
					output[outPos] = currOut[outCount % 8];
					outPos++;
					outCount++;
				} while (outCount % 8);
				return 0;
			}
		}
	}
	@nogc @safe pure nothrow {
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
/**
 * Mcoded7 decode.
 *
 * Uses either a classical length-pointer pair for nogc targets, or D's own dynamic arrays for gc targets.
 */
struct MCoded7Decoder {
	private size_t		counter;	///The amount of encoded data.
	private size_t		outCount;	///The amount of outputted data.
	private ubyte[8]	currIn;		///The currently outputted data.
	private ubyte[7]	currOut;	///The currently inputted data.
	private ubyte		flags;		///Status flags. Bit 7 is set if finalization is complete
	version (midi2_nogc) {
		private size_t			inSize;	///The remaining data in the input stream
		private const(ubyte)*	input;	///The pointer to the current byte in the input stream
		private size_t			outSize;///The remaining data in the output stream
		private ubyte*			output;	///The pointer to the current first byte in the output stream
	} else {
		private const(ubyte)[]	input;	///The input stream
		private ubyte[]			output;	///The output stream
		private size_t			inPos;	///Input position
		private size_t			outPos;	///Output position
	}
	version (midi2_nogc) {
		@nogc @safe pure nothrow{
			/**
			 * Creates a standard decoder with the supplied streams.
			 */
			this(size_t inSize, const(ubyte)* input, size_t outSize, ubyte* output) {
				this.inSize = inSize;
				this.Input = Input;
				this.outSize = outSize;
				this.output = output;
			}
			/**
			 * Encodes all possible data on the input stream without needing to pad out the end
			 */
			MCoded7Status decode() @trusted {
				if (outCount % 8) {		//empty output if needed
					if (emptyOutputChunk())
						return MCoded7Status.NeedsMoreOutput;
				}
				if (!flags & 0x80) {
					while (inSize) {
						if (fillInputChunk())
							return MCoded7Status.AllInputConsumed;
						decodeChunk();
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
				//Encode everything if it still haven't been
				MCoded7Status state = decode();
				//At this point, the output must have enough space to accomodate an extra chunk. If not, then error 
				//out with the NeedsMoreOutput code.
				if (state == MCoded7Status.NeedsMoreOutput || outSize < 8)
					return state;
				currOut = [0,0,0,0,0,0,0];
				encodeChunk();
				if (emptyOutputChunk())
					return MCoded7Status.NeedsMoreOutput;
				flags |= 0x80;
				return MCoded7Status.Finished;
			}
			/**
			 * Sets the input stream.
			 */
			void setInputStream(const(ubyte)* input, size_t inSize) {
				this.input = input;
				this.inSize = inSize;
			}
			/**
			 * Sets the output stream.
			 */
			void setOutputStream(ubyte* output, size_t outSize) {
				this.output = output;
				this.outSize = outSize;
			}
			/**
			 * Fills input chunk.
			 * Returns the amount that is missing from the input, -1 if there's none on the input stream, 0 if 
			 * everything went alright.
			 */
			protected int fillInputChunk() @system {
				if (!inSize) return -1;
				do {
					if (!inSize) return counter % 8;
					currIn[counter % 8] = *input;
					input++;
					inSize--;
					counter++;
				} while (counter % 8);
				return 0;
			}
			/**
			 * Empties output chunk.
			 * Returns the amough that is missing from the input, -1 if there's none on the output stream, 0 
			 * if everything went alright
			 */
			protected int emptyOutputChunk() @system {
				if (!outSize) return -1;
				do {
					if (!outSize) return outCount % 7;
					*output = currOut[counter % 7];
					output++;
					outSize--;
					outCount++;
				} while (outCount % 7);
				return 0;
			}
		}
	} else {
		@nogc @safe pure nothrow {
			/**
			 * Creates a standard decoder with the supplied streams.
			 */
			this (const(ubyte)[] input, ubyte[] output) {
				this.input = input;
				this.output = output;
			}
			/**
			 * Encodes all possible data on the input stream without needing to pad out the end
			 */
			MCoded7Status decode() @trusted {
				if (outCount % 8) {		//empty output if needed
					if (emptyOutputChunk())
						return MCoded7Status.NeedsMoreOutput;
				}
				if (!flags & 0x80) {
					while (input.length < inPos) {
						if (fillInputChunk())
							return MCoded7Status.AllInputConsumed;
						decodeChunk();
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
				MCoded7Status state = decode();
				if (state == MCoded7Status.NeedsMoreOutput)
					return state;
				currOut = [0,0,0,0,0,0,0];
				decodeChunk();
				if (emptyOutputChunk())
					return MCoded7Status.NeedsMoreOutput;
				flags |= 0x80;
				return MCoded7Status.Finished;
			
			}
			/**
			 * Fills the current input chunk from the input stream and raises the counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-6 if the input chunk isn't complete. Returns -1 if
			 * there's no input left
			 */
			protected int fillInputChunk() {
				if (input.length == inPos) return -1;
				do {
					if (input.length == inPos) return counter % 8;
					currIn[counter % 8] = input[inPos];
					inPos++;
					counter++;
				} while (counter % 8);
				return 0;
			}
			/**
			 * Empties the current output chunk to the output stream, and raises the output counter by the amount.
			 * Returns 0 if the chunk is completed. Returns 1-7 if the chunk isn't complete.
			 */
			protected int emptyOutputChunk() {
				if (output.length == outPos) return -1;
				do {
					if (output.length == outPos) return outCount % 7;
					output[outPos] = currOut[outCount % 7];
					outPos++;
					outCount++;
				} while (outCount % 7);
				return 0;
			}
			/**
			 * Sets the input stream.
			 */
			void setInputStream(const(ubyte)[] input) {
				this.input = input;
				inPos = 0;
			}
			/**
			 * Sets the output stream.
			 */
			void setOutputStream(ubyte[] output) {
				this.output = output;
				outPos = 0;
			}
		}
	}
	@nogc @safe pure nothrow {
		/**
		 * Decodes an Mcoded7 chunk.
		 */
		protected void decodeChunk() {
			for (int i ; i < 7 ; i++) {
				currOut[i] = cast(ubyte)((currIn[0] << (1 + i) & 0x80) | currIn[i + 1]);
			}
		}

	}
}


version (midi2_nogc) {
	@nogc nothrow unittest {

	}
} else {
	unittest {
		import std.stdio;
		const(char)[] input = "this is a test!";
		char[] output;
		ubyte[] encoded;
		encoded.length = 16;
		output.length = input.length;
		MCoded7Encoder encoder = MCoded7Encoder(cast(const(ubyte)[])input, encoded);
		MCoded7Status status = encoder.finalize;
		assert(status == MCoded7Status.Finished);
		writeln(cast(char[])encoded);
		MCoded7Decoder decoder = MCoded7Decoder(cast(const(ubyte)[])encoded, cast(ubyte[])output);
		status = decoder.finalize;
		assert(status == MCoded7Status.Finished);
		assert(input == output, output);
	}
}