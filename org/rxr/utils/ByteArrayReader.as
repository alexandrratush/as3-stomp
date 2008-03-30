package org.rxr.utils
{
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;

	public class ByteArrayReader extends ByteArray
	{
		
		public function readLine(): String
		{
			return readUntilChar("\n");
		}

		public function readUntilChar(char: String): String
		{
			var ba: ByteArray = readUntilByte(char.charCodeAt());
			ba.position = 0;
			return ba.readUTFBytes(ba.length);			
		}

		public function readUntilString(string: String): String
		{
			var ba: ByteArray = readUntilBytes(stringToBytes(string));
			ba.position = 0;
			return ba.readUTFBytes(ba.length);			
		}
		
		public function readUntilByte(byte: int): ByteArray
		{
			var bytes:ByteArray;
			var byteIndex: int = scan(byte);
			if(byteIndex != -1)
			{
				bytes = new ByteArray();
				readBytes(bytes, 0, byteIndex)
				position++;				
			}

			return bytes;
		}

		public function readUntilBytes(bytes: ByteArray): ByteArray
		{
			var ba:ByteArray;
			var byteIndex: int = indexOf(bytes);
			if(byteIndex != -1)
			{
				ba = new ByteArray();
				readBytes(ba, 0, byteIndex)
				position++;				
			}

			return ba;
		}
		
		public function readFor(length: uint): ByteArray
		{
			var bytes:ByteArray = new ByteArray();
			readBytes(bytes, 0, length);
			return bytes;
		}
		
		
		public function splitByte(byte: int) : Array
		{
			for( var items: Array = [], byteIndex: int = scan(byte); 
				 byteIndex!= -1;
				 items.push(readFor(byteIndex)), position++, byteIndex = scan(byte) 
			   );
			   
			if (bytesAvailable > 0) items.push(readFor(bytesAvailable));
			
			return items;		
		}
		
		
		public function scan(byte: int, offset: int = 0): int
		{
			var index: int = -1;
			for (var i: int=offset; i<bytesAvailable; i++){
				if (peek(i) == byte){
					index = i; 
					break;
				}
			}
			
			return index;
		}


		public function scanBack(byte: int, offset: int = 0): int
		{
			var index: int = -1;
			for (var i:int=length-offset; i>position; i--){
				if (peek(i) == byte){
					index = i; 
					break;
				}
			}
			
			return index - position;
		}

		public function peek(offset: int): int
		{
			return this[position + offset];
		}
		
		public function forward(): void
		{
			position++;
		}
		
		public function forwardBy(num: uint): void
		{
			position+=num;
		}
		
		public function indexOf(bytes: ByteArray): int
		{
			var index: int = -1;
			const firstByte: int = bytes[0];
			const len : int = bytes.length;		
			
			for(var start: int = scan(firstByte); 
			    start != -1 && (start + len) < bytesAvailable; 
			    start = scan(firstByte, start+1)) {
			    	
				var match: Boolean = true;				
				innerloop:{ 
					for (var i: uint=1, halfLen:Number=len/2+1; i<halfLen; i++) {
						if(bytes[i] != peek(start + i) ||  bytes[len - i] != peek((start + len) - i)){
							match = false;
							break innerloop;
						}							
					}	
				}				
				if (match) {
					index = start;
					break;
				}	
			}
			
			return index;
		}
		
		
		public function indexOfString(string: String): int
		{
			return indexOf(stringToBytes(string));
		}
		
		public function stringToBytes(string: String) : ByteArray
		{
			var bytes: ByteArray = new ByteArray();
			bytes.writeUTFBytes(string);
			return bytes;
		}
		
		public function ByteArrayReader(source: IDataInput = null)
		{
			super();
			if (source){ source.readBytes(this, 0, source.bytesAvailable); position=0}
		}
		

		
	}
}