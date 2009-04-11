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
 	Version 0.41 : Derek Wischusen (dwischus at flexonrails dot net) and Peter Mulreid.  
 */

package org.codehaus.stomp {
	
	import flash.events.*;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
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
		
    	private var socket : Socket;
 		
 		private var buffer:ByteArrayReader = new ByteArrayReader();
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

		}
	
		public function connect( server : String = "localhost", port : int = 61613, connectHeaders : ConnectHeaders = null, socket: Socket = null) : void 
		{
			this.server = server;
			this.port = port
			this.connectHeaders = connectHeaders;
			this.socket = socket || new Socket();
			
			initializeSocket();
			doConnect();
		}

		public function exit() : void 
		{
			expectDisconnect = true;
			socket.close();
		}
		
		private function initializeSocket(): void
		{
			socket.addEventListener( Event.CONNECT, onConnect );
	  		socket.addEventListener( Event.CLOSE, onClose );
      		socket.addEventListener( ProgressEvent.SOCKET_DATA, onData );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onError );			
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

 	   	protected function onConnect( event:Event ) : void 
 	   	{
			if (connectTimer && connectTimer.running) connectTimer.stop();
			
			dispatchEvent(event.clone());
			
			var h : Object = connectHeaders ? connectHeaders.getHeaders() : {}; 
			transmit("CONNECT", h);
			socketConnected = true;
			
			this.dispatchEvent(event.clone());
    	}
	
		protected function onClose( event:Event ) : void 
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
			
			this.dispatchEvent(event.clone());
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
			this.dispatchEvent(event.clone());
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
			else 
				messageBytes.writeObject(message);

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
	    	if (buffer.bytesAvailable == 0)
	    		buffer.length = 0;
	    	socket.readBytes(buffer, buffer.length, socket.bytesAvailable);
	    	while (buffer.bytesAvailable > 0 && processFrame()) {
	    		// processFrame called once per iteration;
	    	}
	    }
	    private function processFrame():Boolean {
			if (!frameReader) {
				frameReader = new FrameReader(buffer);
			} else {
				frameReader.processBytes();
			}
			if (frameReader.isComplete) {
				dispatchFrame(frameReader.command, frameReader.headers, frameReader.body);
				frameReader = null;
				return true;
			} else {
				return false;
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
					throw new Error("UNKNOWN STOMP FRAME '"+command+"'");
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
	public var body : ByteArray = new ByteArray();
	private var bodyProcessed:Boolean = false;
	
	public function get isComplete(): Boolean
	{
		return frameComplete;
	}
	
	public function readBytes(data: IDataInput): void
	{
		data.readBytes(reader, reader.length, data.bytesAvailable);
		processBytes();
	}
	
	public function processBytes(): void
	{
		if (!command && reader.scan(0x0A) != -1)
			processCommand();

		if (command && !headers && reader.indexOfString("\n\n") != -1)
			processHeaders();
		
		if (command && headers && (bodyProcessed=bodyComplete()))
			processBody();
		
		if (command && headers && bodyProcessed)
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
		while (reader.bytesAvailable > 0 && reader.peek(0) <= 27) {
			reader.forward();
		}
		body.position=0;
	}
	
	private function bodyComplete() : Boolean {
		if(contentLength != -1) {
			if(contentLength > reader.bytesAvailable + body.length) {
				body.writeBytes(reader.readFor(reader.bytesAvailable));
				return false;
			} else {
				body.writeBytes(reader.readFor(contentLength));
			}
		} else {
			var nullByteIndex: int = reader.scan(0x00);
			if(nullByteIndex != -1) {
				if (nullByteIndex > 0) {
					body.writeBytes(reader.readFor(nullByteIndex));	
				}
				contentLength = body.length;
			} else {
				body.writeBytes(reader.readFor(reader.bytesAvailable));
				return false;
			}
		}
		return true;
	}
	
	public function FrameReader(reader: ByteArrayReader): void
	{
		this.reader = reader;
		processBytes();
	}
}
	
