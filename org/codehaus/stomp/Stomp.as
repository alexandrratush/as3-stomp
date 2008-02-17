/**
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
 /*
 	Version 0.1 : R Jewson (rjewson at gmail dot com).  First release, only for reciept of messages.
 	Version 0.4 : Derek Wischusen (dwischus at flexonrails dot net).  
 */

package org.codehaus.stomp {
	
	import flash.events.*;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import mx.utils.ObjectUtil;
	
	import org.codehaus.stomp.event.*;
	import org.codehaus.stomp.frame.*;
	import org.codehaus.stomp.headers.*;
	import org.rxr.utils.ByteArrayReader;
	
	[Event(name="connected", type="org.codehaus.stomp.event.ConnectedEvent")]
	
	[Event(name="message", type="org.codehaus.stomp.event.MessageEvent")]
	
	[Event(name="receipt", type="org.codehaus.stomp.event.ReceiptEvent")]
	
	[Event(name="fault", type="org.codehaus.stomp.event.STOMPErrorEvent")]
	
	public class Stomp extends EventDispatcher {
  
		private static const NEWLINE : String = "\n";
		private static const BODY_START : String = "\n\n";
		private static const NULL_BYTE : int = 0x00;
		
    	private const socket : Socket = new Socket();
 		
		private var server : String;
		private var port : int;
		private var connectHeaders : ConnectHeaders;			
  		private var socketConnected : Boolean   = false;
		private var protocolPending : Boolean   = false;
		private var protocolConnected : Boolean = false;
		private var expectDisconnect : Boolean  = false;
		private var connectTimer : Timer;
		private var subscriptions : Array = new Array();
		
		public var errorMessages : Array = new Array();
		public var sessionID : String;
		public var connectTime : Date;
		public var disconnectTime : Date;
		public var autoReconnect : Boolean = true;
				
  		public function Stomp() 
  		{
			socket.addEventListener( Event.CONNECT, onConnect );
	  		socket.addEventListener( Event.CLOSE, onClose );
      		socket.addEventListener( ProgressEvent.SOCKET_DATA, onData );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onError );
		}
	
		public function connect( server : String = "localhost", port : int = 61613, connectHeaders : ConnectHeaders = null) : void 
		{
			this.server = server;
			this.port = port
			this.connectHeaders = connectHeaders;
			doConnect();
		}

		public function exit() : void 
		{
			expectDisconnect = true;
			socket.close();
		}
		
		private function doConnect() : void 
		{
			if (socketConnected==true)
				return;
			socket.connect( server, int(port) );
			socketConnected = false;
			protocolConnected = false;
			protocolPending = true;
			expectDisconnect = false;
		}

 	   	private function onConnect( event:Event ) : void 
 	   	{
			if (connectTimer && connectTimer.running) connectTimer.stop();
			
			var h : Object = connectHeaders ? connectHeaders.getHeaders() : {}; 
			transmit("CONNECT", h);
			socketConnected = true;
    	}
	
		private function onClose( event:Event ) : void 
		{
			socketConnected = false;
			protocolConnected = false;
			protocolPending = false;
			disconnectTime = new Date();

			if (!expectDisconnect && autoReconnect) 
			{
				connectTimer = new Timer(2000, 5);
				connectTimer.addEventListener(TimerEvent.TIMER, doConnectTimer);
				connectTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimerComplete);
				connectTimer.start();
			}
		}

		private function doConnectTimer( event:TimerEvent ):void 
		{
			doConnect();
		}
		
		private function onTimerComplete( event:TimerEvent ):void
		{
			if (!socket.connected) throw new Error("Unable to reconnect to socket");
		} 
		

		private function onError( event:Event ) : void 
		{
			var now:Date = new Date();
			if (!socket.connected) {
				socketConnected = false;
				protocolConnected = false;
				protocolPending = false;
				disconnectTime = now;
			}
			errorMessages.push(now + " " + event.type);
		}
		
		public function subscribe(destination : String, headers : SubscribeHeaders = null) : void 
		{

			var h : Object = headers ? headers.getHeaders() : null;
				
			if (socketConnected)
			{
				if (!h) h = {};
				
				h['destination'] = destination;
				transmit("SUBSCRIBE", h);
			}
			
			subscriptions.push({destination: destination, headers: headers, connected: socketConnected});

		}
		
		public function send (destination : String, message : Object, headers : SendHeaders = null) : void
		{
			var h : Object = headers ? headers.getHeaders() : {};				
			h['destination'] = destination;
			
			var messageBytes : ByteArray = new ByteArray();					
			if(message is ByteArray) 
				messageBytes.writeBytes(ByteArray(message), 0, message.length);
			else if(message is String)
				messageBytes.writeUTFBytes(String(message));
			else if(message is int)
				messageBytes.writeInt(int(message));
			else if(message is Number)
				messageBytes.writeDouble(Number(message));
			else if(message is Boolean)
				messageBytes.writeBoolean(Boolean(message));
			else if(!ObjectUtil.isSimple(message))
				messageBytes.writeObject(message);
			else if(message is Array)
				messageBytes.writeObject(message as Array);

			h['content-length'] = messageBytes.length;

			transmit("SEND", h,  messageBytes);
		}
		
		public function sendTextMessage(destination : String, message : String, headers : SendHeaders = null) : void
		{
			var h : Object = headers ? headers.getHeaders() : {};
			h['destination'] = destination;
			
			var messageBytes : ByteArray = new ByteArray();
			messageBytes.writeUTFBytes(message);
			
			transmit("SEND", h,  messageBytes);
		}
		
		public function begin (transaction : String, headers : BeginHeaders = null) : void
		{
			var h : Object = headers ? headers.getHeaders() : {};
				
			h['transaction'] = transaction;
			transmit("BEGIN", h);
		}

		public function commit (transaction : String, headers : CommitHeaders = null) : void
		{
			var h : Object = headers ? headers.getHeaders() : {};
				
			h['transaction'] = transaction;
			transmit("COMMIT", h);
		}
		
		public function ack (messageID : String, headers : AckHeaders = null) : void
		{
			var h : Object = headers ? headers.getHeaders() : {};
				
			h['message-id'] = messageID;
			transmit("ACK", h);
		}
		
		public function abort (transaction : String, headers : AbortHeaders = null) : void
		{
			var h : Object = headers ? headers.getHeaders() : {};
				
			h['transaction'] = transaction;
			transmit("ABORT", h);
		}		
		
		public function unsubscribe (destination : String, headers : UnsubscribeHeaders = null) : void
		{
			var h : Object = headers ? headers.getHeaders() : {};
				
			h['destination'] = destination;
			transmit("UNSUBSCRIBE", h);
		}
		
		public function disconnect () : void
		{
			transmit("DISCONNECT", {});
		}	
		
		private function transmit (command : String, headers : Object, body : ByteArray = null) : void
		{
			var transmission : ByteArray = new ByteArray();
			transmission.writeUTFBytes(command);

			for (var header: String in headers)
				transmission.writeUTFBytes( NEWLINE + header + ":" + headers[header] );	       
	        
	        transmission.writeUTFBytes( BODY_START );
			if (body) transmission.writeBytes( body, 0, body.length )
	        transmission.writeByte( NULL_BYTE );
	        
	        socket.writeBytes( transmission, 0, transmission.length );
	        socket.flush();
		
		}
		
		private function processSubscriptions() : void 
		{
			for each (var sub : Object in subscriptions)
			{
				if (sub['connected'] == false)
					this.subscribe(sub['destination'], SubscribeHeaders(sub['headers']));
			}
		}
	
		private var frameReader : FrameReader;
		
	    private function onData(event : ProgressEvent):void {
			
			if (!frameReader)
				frameReader = new FrameReader(new ByteArrayReader(socket));
			else if(!frameReader.isComplete)
				frameReader.readBytes(socket)
			
			if (frameReader.isComplete) {
				dispatchFrame(frameReader.command, frameReader.headers, frameReader.body);
				frameReader = null;
			}
					
		}


		private function dispatchFrame(command: String, headers: Object, body: ByteArray): void
		{
			switch (command) 
			{				
				case "CONNECTED":
					protocolConnected = true;
					protocolPending = false;
					expectDisconnect = false;
					connectTime = new Date();
					sessionID = headers['session'];
					processSubscriptions();
					dispatchEvent(new ConnectedEvent(ConnectedEvent.CONNECTED));				
				break;
				
				case "MESSAGE":
					var messageEvent : MessageEvent = new MessageEvent(MessageEvent.MESSAGE);
					messageEvent.message = new MessageFrame(body, headers);
					dispatchEvent(messageEvent);
				break;
				
				case "RECEIPT":
					var receiptEvent : ReceiptEvent = new ReceiptEvent(ReceiptEvent.RECEIPT);
					receiptEvent.receiptID = headers['receipt-id'];
					dispatchEvent(receiptEvent);
				break;
				
				case "ERROR":
					var errorEvent : STOMPErrorEvent = new STOMPErrorEvent(STOMPErrorEvent.ERROR);
					errorEvent.error = new ErrorFrame(body, headers);
					dispatchEvent(errorEvent);					
				break;
				
				default:
					throw new Error("UNKNOWN STOMP FRAME");
				break;
				
			}			
		}
  	}
}


import org.rxr.utils.ByteArrayReader;
import flash.utils.ByteArray;
import flash.utils.IDataInput;
import org.codehaus.stomp.Stomp;
	
internal class FrameReader {
	
	private var reader : ByteArrayReader;
	private var frameComplete: Boolean = false;
	private var contentLength: int = -1;
	
	public var command : String;
	public var headers : Object;
	public var body : ByteArray;
	
	public function get isComplete(): Boolean
	{
		return frameComplete;
	}
	
	public function readBytes(data: IDataInput): void
	{
		data.readBytes(reader, reader.length, data.bytesAvailable);
		processBytes();
	}
	
	private function processBytes(): void
	{
		if (!command && reader.scan(0x0A) != -1)
			processCommand();
		
		if (command && !headers && reader.indexOfString("\n\n") != -1)
			processHeaders();
		
		if (command && headers && bodyComplete())
			processBody();
		
		if (command && headers && body)
			frameComplete = true;
						
	}

	private function processCommand(): void
	{
		command = reader.readLine();
	}
	
	private function processHeaders(): void
	{
		headers = new Object();
					
		var headerString : String = reader.readUntilString("\n\n");
		var headerValuePairs : Array = headerString.split("\n");
		
		for each (var pair : String in headerValuePairs) 
		{
			var separator : int = pair.indexOf(":");
			headers[pair.substring(0, separator)] = pair.substring(separator+1);
		}
		
		if(headers["content-length"])
			contentLength = headers["content-length"];
		
		reader.forward();		
	}
	
	private function processBody(): void
	{
	 	body = reader.readFor(contentLength);	
	}
	
	private function bodyComplete() : Boolean
	{
		if(contentLength != -1) {
			if(contentLength > reader.bytesAvailable)
				return false
		}
		else {
			var nullByteIndex: int = reader.scanBack(0x00);
			if(nullByteIndex != -1)
				contentLength = nullByteIndex;	
			else
				return false
		}

		return true
	}
	
	public function FrameReader(reader: ByteArrayReader): void
	{
		this.reader = reader;
		processBytes();
	}
					
	
}
	
