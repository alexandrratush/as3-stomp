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
package org.codehaus.stomp
{
    import flash.errors.IOError;
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
    [Event(name="reconnectFailed", type="org.codehaus.stomp.event.ReconnectFailedEvent")]
    [Event(name="ioError", type="flash.events.IOErrorEvent")]
    [Event(name="securityError", type="flash.events.SecurityErrorEvent")]

    public class Stomp extends EventDispatcher
    {
        private static const NEWLINE:String = "\n";
        private static const BODY_START:String = "\n\n";
        private static const NULL_BYTE:int = 0x00;

        public var errorMessages:Array = [];
        public var sessionID:String;
        public var connectTime:Date;
        public var disconnectTime:Date;
        public var autoReconnect:Boolean = true;

        private var _socket:Socket;
        private var _byteArrayReader:ByteArrayReader;
        private var _frameReader:FrameReader;
        private var _server:String;
        private var _port:int;
        private var _connectHeaders:ConnectHeaders;
        private var _connectTimer:Timer;
        private var _subscriptions:Array;

        public function Stomp()
        {
            _byteArrayReader = new ByteArrayReader();
            _subscriptions = [];
        }

        public function connect(server:String = "localhost", port:int = 61613, connectHeaders:ConnectHeaders = null, socket:Socket = null):void
        {
            _server = server;
            _port = port;
            _connectHeaders = connectHeaders;
            _socket = socket || new Socket();

            removeSocketEventListeners();
            addSocketEventListeners();
            doConnect();
        }

        public function close():void
        {
            if (_connectTimer && _connectTimer.running)
                stopAutoReconnect();

            try
            {
                if (_socket.connected)
                    disconnect();

                _socket.close();
            } catch (error:Error)
            {
                trace("Non-critical error closing _socket ", error.toString());
            }
        }

        public function stopAutoReconnect():void
        {
            if (_connectTimer)
            {
                _connectTimer.stop();
                _connectTimer.removeEventListener(TimerEvent.TIMER, doConnectTimer);
                _connectTimer = null;
            }
        }

        private function addSocketEventListeners():void
        {
            _socket.addEventListener(Event.CONNECT, onConnect);
            _socket.addEventListener(Event.CLOSE, onClose);
            _socket.addEventListener(ProgressEvent.SOCKET_DATA, onData);
            _socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
            _socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
        }

        private function removeSocketEventListeners():void
        {
            if (_socket != null)
            {
                _socket.addEventListener(Event.CONNECT, onConnect);
                _socket.addEventListener(Event.CLOSE, onClose);
                _socket.addEventListener(ProgressEvent.SOCKET_DATA, onData);
                _socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
                _socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
            }
        }

        private function doConnect():void
        {
            if (!_socket.connected)
            {
                try
                {
                    _socket.connect(_server, int(_port));
                } catch (error:Error)
                {
                    trace("doConnect error: " + error.toString());
                }
            }
        }

        protected function onConnect(event:Event):void
        {
            if (_connectTimer && _connectTimer.running)
                stopAutoReconnect();

            var h:Object = _connectHeaders ? _connectHeaders.getHeaders() : {};
            transmit("CONNECT", h);

            dispatchEvent(event);
        }

        protected function tryAutoreconnect():void
        {
            if (!_socket.connected && autoReconnect && (_connectTimer == null || !_connectTimer.running))
            {
                // try every minute, repeating indefinitely (want it to be longer than _socket timeouts)
                _connectTimer = new Timer(60000, 0);
                _connectTimer.addEventListener(TimerEvent.TIMER, doConnectTimer);
                _connectTimer.start();
            }
        }

        // these are always unexpected close events (they don't result from us calling _socket.close() (see docs))
        protected function onClose(event:Event):void
        {
            disconnectTime = new Date();
            tryAutoreconnect();
            dispatchEvent(event);
        }

        private function doConnectTimer(event:TimerEvent):void
        {
            if (!_socket.connected)
            {
                doConnect();
            }
        }

        private function onError(event:Event):void
        {
            var now:Date = new Date();

            try
            {
                _socket.close();
            } catch (error:IOError)
            {
                trace("IOError", error.toString());
            }

            if (_connectTimer != null && _connectTimer.running)
            {
                dispatchEvent(new ReconnectFailedEvent(ReconnectFailedEvent.RECONNECT_FAILED));
            }
            else
            {
                disconnectTime = now;
                tryAutoreconnect();

                errorMessages.push(now + " " + event.type);
                dispatchEvent(event);
            }
        }

        public function subscribe(destination:String, headers:SubscribeHeaders = null):void
        {
            if (_socket.connected)
            {
                var h:Object = headers ? headers.getHeaders() : {};
                h["destination"] = destination;
                transmit("SUBSCRIBE", h);
            }

            _subscriptions.push({destination: destination, headers: headers, connected: _socket.connected});
        }

        public function send(destination:String, message:Object, headers:SendHeaders = null):void
        {
            var h:Object = headers ? headers.getHeaders() : {};
            h["destination"] = destination;

            var messageBytes:ByteArray = new ByteArray();
            if (message is ByteArray)
                messageBytes.writeBytes(ByteArray(message), 0, message.length);
            else if (message is String)
                messageBytes.writeUTFBytes(String(message));
            else if (message is int)
                messageBytes.writeInt(int(message));
            else if (message is Number)
                messageBytes.writeDouble(Number(message));
            else if (message is Boolean)
                messageBytes.writeBoolean(Boolean(message));
            else
                messageBytes.writeObject(message);

            h["content-length"] = messageBytes.length;

            transmit("SEND", h, messageBytes);
        }

        public function sendTextMessage(destination:String, message:String, headers:SendHeaders = null):void
        {
            var h:Object = headers ? headers.getHeaders() : {};
            h["destination"] = destination;

            var messageBytes:ByteArray = new ByteArray();
            messageBytes.writeUTFBytes(message);

            transmit("SEND", h, messageBytes);
        }

        public function begin(transaction:String, headers:BeginHeaders = null):void
        {
            var h:Object = headers ? headers.getHeaders() : {};
            h["transaction"] = transaction;
            transmit("BEGIN", h);
        }

        public function commit(transaction:String, headers:CommitHeaders = null):void
        {
            var h:Object = headers ? headers.getHeaders() : {};
            h["transaction"] = transaction;
            transmit("COMMIT", h);
        }

        public function ack(messageID:String, headers:AckHeaders = null):void
        {
            var h:Object = headers ? headers.getHeaders() : {};
            h["message-id"] = messageID;
            transmit("ACK", h);
        }

        public function abort(transaction:String, headers:AbortHeaders = null):void
        {
            var h:Object = headers ? headers.getHeaders() : {};
            h["transaction"] = transaction;
            transmit("ABORT", h);
        }

        public function unsubscribe(destination:String, headers:UnSubscribeHeaders = null):void
        {
            var h:Object = headers ? headers.getHeaders() : {};
            h["destination"] = destination;
            transmit("UNSUBSCRIBE", h);
        }

        public function disconnect():void
        {
            transmit("DISCONNECT", {});
        }

        private function transmit(command:String, headers:Object, body:ByteArray = null):void
        {
            var transmission:ByteArray = new ByteArray();
            transmission.writeUTFBytes(command);

            for (var header:String in headers)
                transmission.writeUTFBytes(NEWLINE + header + ":" + headers[header]);

            transmission.writeUTFBytes(BODY_START);
            if (body != null) transmission.writeBytes(body, 0, body.length);
            transmission.writeByte(NULL_BYTE);

            try
            {
                _socket.writeBytes(transmission, 0, transmission.length);
                _socket.flush();
            } catch (error:Error)
            {
                dispatchEvent(new STOMPErrorEvent(STOMPErrorEvent.TRANSMIT_ERROR, new ErrorFrame(body, headers), command));
            }
        }

        private function processSubscriptions():void
        {
            for each (var sub:Object in _subscriptions)
            {
                if (sub["connected"] == false)
                    this.subscribe(sub["destination"], SubscribeHeaders(sub["headers"]));
            }
        }

        private function onData(event:ProgressEvent):void
        {
            if (_byteArrayReader.bytesAvailable == 0)
                _byteArrayReader.length = 0;
            _socket.readBytes(_byteArrayReader, _byteArrayReader.length, _socket.bytesAvailable);
            while (_byteArrayReader.bytesAvailable > 0 && processFrame())
            {
                // processFrame called once per iteration;
            }
        }

        private function processFrame():Boolean
        {
            if (!_frameReader)
                _frameReader = new FrameReader(_byteArrayReader);
            else
                _frameReader.processBytes();

            if (_frameReader.isComplete)
            {
                dispatchFrame(_frameReader.command, _frameReader.headers, _frameReader.body);
                _frameReader = null;
                return true;
            }
            else
            {
                return false;
            }
        }

        private function dispatchFrame(command:String, headers:Object, body:ByteArray):void
        {
            switch (command)
            {
                case "CONNECTED":
                    connectTime = new Date();
                    sessionID = headers["session"];
                    processSubscriptions();
                    dispatchEvent(new ConnectedEvent(ConnectedEvent.CONNECTED));
                    break;

                case "MESSAGE":
                    var messageEvent:MessageEvent = new MessageEvent(MessageEvent.MESSAGE);
                    messageEvent.message = new MessageFrame(body, headers);
                    dispatchEvent(messageEvent);
                    break;

                case "RECEIPT":
                    var receiptEvent:ReceiptEvent = new ReceiptEvent(ReceiptEvent.RECEIPT);
                    receiptEvent.receiptID = headers["receipt-id"];
                    dispatchEvent(receiptEvent);
                    break;

                case "ERROR":
                    dispatchEvent(new STOMPErrorEvent(STOMPErrorEvent.ERROR, new ErrorFrame(body, headers)));
                    break;

                default:
                    dispatchEvent(new STOMPErrorEvent(STOMPErrorEvent.UNKNOWN_STOMP_FRAME, new ErrorFrame(body, headers)));
                    break;

            }
        }
    }
}


import flash.utils.ByteArray;
import flash.utils.IDataInput;

import org.rxr.utils.ByteArrayReader;

internal class FrameReader
{

    private var reader:ByteArrayReader;
    private var frameComplete:Boolean = false;
    private var contentLength:int = -1;

    public var command:String;
    public var headers:Object;
    public var body:ByteArray = new ByteArray();
    private var bodyProcessed:Boolean = false;

    public function get isComplete():Boolean
    {
        return frameComplete;
    }

    public function readBytes(data:IDataInput):void
    {
        data.readBytes(reader, reader.length, data.bytesAvailable);
        processBytes();
    }

    public function processBytes():void
    {
        if (!command && reader.scan(0x0A) != -1)
            processCommand();

        if (command && !headers && reader.indexOfString("\n\n") != -1)
            processHeaders();

        if (command && headers && (bodyProcessed = bodyComplete()))
            processBody();

        if (command && headers && bodyProcessed)
            frameComplete = true;
    }

    private function processCommand():void
    {
        command = reader.readLine();
    }

    private function processHeaders():void
    {
        headers = {};

        var headerString:String = reader.readUntilString("\n\n");
        var headerValuePairs:Array = headerString.split("\n");

        for each (var pair:String in headerValuePairs)
        {
            var separator:int = pair.indexOf(":");
            headers[pair.substring(0, separator)] = pair.substring(separator + 1);
        }

        if (headers["content-length"])
            contentLength = headers["content-length"];

        reader.forward();
    }

    private function processBody():void
    {
        while (reader.bytesAvailable > 0 && reader.peek(0x00) <= 27)
        {
            reader.forward();
        }
        body.position = 0;
    }

    private function bodyComplete():Boolean
    {
        if (contentLength != -1)
        {
            const len:int = body.length;
            if (contentLength > reader.bytesAvailable + len)
            {
                body.writeBytes(reader.readFor(reader.bytesAvailable));
                return false;
            }
            else
            {
                body.writeBytes(reader.readFor(contentLength - len));
            }
        }
        else
        {
            var nullByteIndex:int = reader.scan(0x00);
            if (nullByteIndex != -1)
            {
                if (nullByteIndex > 0)
                    body.writeBytes(reader.readFor(nullByteIndex));

                contentLength = body.length;
            }
            else
            {
                body.writeBytes(reader.readFor(reader.bytesAvailable));
                return false;
            }
        }
        return true;
    }

    public function FrameReader(reader:ByteArrayReader):void
    {
        this.reader = reader;
        processBytes();
    }
}
	
