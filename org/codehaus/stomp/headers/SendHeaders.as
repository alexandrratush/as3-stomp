/**
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

package org.codehaus.stomp.headers
{
	public class SendHeaders extends Headers
	{

		// The following headers are for mapping to JMS Brokers.
		// The header descriptions are from: http://activemq.apache.org/stomp.html
		
		/**
		 * Maps To: JMSCorrelationID 	 
		 * Good consumers will add this header to any responses they send
		 **/
		public static const CORRELATION_ID : String =  "correlation-id";
		 	
		/**
		 * JMSExpiration 	
		 * Expiration time of the message
		 **/
		public static const EXPIRES : String =  "expires";
		
		/**
		 * Maps To: JMSDeliveryMode 	
		 * Whether or not the message is persistent
		 */
		public static const PERSISTANT : String = "persistent";
		
		/**
		 * Maps To: JMSPriority 	
		 * Priority on the message
		 **/
		public static const PRIORITY : String =  "priority"; 	
		
		/**
		 * Maps To: JMSReplyTo 	
		 * Destination you should send replies to
		 **/
		public static const REPLY_TO : String = "reply-to";
		
		/** 
		 * Maps To: JMSType 	
		 * Type of the message
		 **/
		public static const TYPE : String = "type";
		
		/** 
		 * Maps To: JMSXGroupID 	
		 * Specifies the Message Groups
		 **/
		public static const JMSX_GROUP_ID : String = "JMSXGroupID";
		
		/**
		 * Maps To: JMSXGroupSeq 	
		 * Optional header that specifies the sequence number in the Message Groups
		 **/
		public static const JMSX_GROUP_SEQ  : String = "JMSXGroupSeq";
		
		/**
		 * Used to bind a message to a named transaction.
		 **/		
		public static const TRANSACTION : String = 'transaction';

		/**
		 *  RabbitMQ/AMQP only
		 */
		public static const EXCHANGE: String = "exchange";
		
		
		public function set receipt (id : String) : void
		{
			addHeader(SharedHeaders.RECEIPT, id);
		}
		
		public function set correlationID (id : String) : void
		{
			addHeader(CORRELATION_ID, id);
		}
		
		public function set expires (time : String) : void
		{
			addHeader(EXPIRES, time);
		}
		
		public function set persistant (isPersistant : String) : void
		{
			addHeader(PERSISTANT, isPersistant);
		}		
		
		public function set priority (priority : String) : void
		{
			addHeader(PRIORITY, priority);
		}
		
		public function set replyTo (destination : String) : void
		{
			addHeader(REPLY_TO, destination);
		}
		
		public function set type (type : String) : void
		{
			addHeader(TYPE, type);
		}
		
		public function set jsmxGroupID (id : String) : void
		{
			addHeader(JMSX_GROUP_ID, id);
		}
		
		public function set jsmxGroupSeq (number : String) : void
		{
			addHeader(JMSX_GROUP_SEQ, number);
		}
		
		public function set transaction (id : String) : void
		{
			addHeader(TRANSACTION, id);
		}

		public function set exchange (exchange : String) : void
		{
			addHeader(EXCHANGE, exchange);
		}			
	}
}