package org.codehaus.stomp.headers
{
	public class Headers
	{
		
		protected var headers : Object =  new Object(); 
		
		public function addHeader (header : String, value : *) : void
		{
			headers[header] = value;
		}
		
		public function getHeaders () : Object
		{
			return headers;
		}
		
	}
}