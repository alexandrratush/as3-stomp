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

package org.codehaus.stomp.headers 
{

	public class SubscribeHeaders extends Headers
	{
	
		public static const ACK : String = "ack";
		public static const ID : String = "id";
		
		
		// The following headers are extensions that are added by ActiveMQ.
		// The header descriptions are from: http://activemq.apache.org/stomp.html
		
		/**
		 * Specifies a JMS Selector using SQL 92 syntax as specified in the JMS 1.1 specificiation. 
		 * This allows a filter to be applied to each message as part of the subscription.
		 **/
		public static const AMQ_SELECTOR : String = "selector";
		
		/**
		 * Should messages be dispatched synchronously or asynchronously from the producer thread for non-durable 
		 * topics in the broker? For fast consumers set this to false. For slow consumers set it to true so that 
		 * dispatching will not block fast consumers.
		 **/	
		public static const AMQ_DISPATCH_ASYNC : String = "activemq.dispatchAsync";
		
		/**
		 * I would like to be an Exclusive Consumer on the queue.
		 **/		
		public static const AMQ_EXCLUSIVE : String = "activemq.exclusive";
		
		/**
		 * For Slow Consumer Handling on non-durable topics by dropping old messages - we can set a maximum-pending 
		 * limit, such that once a slow consumer backs up to this high water mark we begin to discard old messages.
		 **/		
		public static const AMQ_MAXIMUM_PENDING_MESSAGE_LIMIT : String = "activemq.maximumPendingMessageLimit";
		
		/**
		 * Specifies whether or not locally sent messages should be ignored for subscriptions. Set to true to 
		 * filter out locally sent messages.
		 **/		
		public static const AMQ_NO_LOCAL : String = "activemq.noLocal";
		
		/**
		 * Specifies the maximum number of pending messages that will be dispatched to the client. Once this maximum 
		 * is reached no more messages are dispatched until the client acknowledges a message. Set to 1 for very 
		 * fair distribution of messages across consumers where processing messages can be slow.
		 **/		
		public static const AMQ_PREFETCH_SIZE : String = "activemq.prefetchSize";
		
		/**
		 * Sets the priority of the consumer so that dispatching can be weighted in priority order.
		 **/		
		public static const AMQ_PRIORITY : String = "activemq.priority";
		
		/**
		 * For non-durable topics make this subscription retroactive.
		 **/		
		public static const AMQ_RETROACTIVE : String = "activemq.retroactive";
		
		/**
		 * For durable topic subscriptions you must specify the same clientId on the connection and 
		 * subcriptionName on the subscribe. Note the spelling: subcriptionName NOT subscriptionName. 
		 * This is not intuitive, but it is how it is implemented for now.
		 **/		
		public static const AMQ_SUBSCRIPTION_NAME : String = "activemq.subcriptionName";
		
		public function set receipt (id : String) : void
		{
			addHeader(SharedHeaders.RECEIPT, id);
		}
				
		public function set ack (mode : String) : void
		{
			addHeader(ACK, mode);
		}
		
		public function set id (id : String) : void
		{
			addHeader(ID, id);
		}
		
		public function set amqSelector (sql : String) : void
		{
			addHeader(AMQ_SELECTOR, sql);
		}
		
		public function set amqDispatchAsync (isAsync : String) : void
		{
			addHeader(AMQ_DISPATCH_ASYNC, isAsync);
		}
		
		public function set amqExclusive (isExclusive : String) : void
		{
			addHeader(AMQ_EXCLUSIVE, isExclusive);
		}
		
		public function set amqMaximumPendingMessageLimit (limit : String) : void
		{
			addHeader(AMQ_MAXIMUM_PENDING_MESSAGE_LIMIT, limit);
		}
		
		public function set amqNoLocal (ignoreLocal : String) : void
		{
			addHeader(AMQ_NO_LOCAL, ignoreLocal);
		}
		
		public function set amqPrefetchSize (size : String) : void
		{
			addHeader(AMQ_PREFETCH_SIZE, size);
		}
		
		public function set amqPriority (priority : String) : void
		{
			addHeader(AMQ_PRIORITY, priority);
		}
		
		public function set amqRetroactive (isRetroactive : String) : void
		{
			addHeader(AMQ_RETROACTIVE, isRetroactive);
		}
		
		public function set amqSubscriptionName (name : String) : void
		{
			addHeader(AMQ_SUBSCRIPTION_NAME, name);
		}
	}
}