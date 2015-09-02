package org.codehaus.stomp.event
{
    import flash.events.Event;

    public class ReconnectFailedEvent extends Event
    {
        public static const RECONNECT_FAILED:String = "reconnectFailed";

        public function ReconnectFailedEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false)
        {
            super(type, bubbles, cancelable);
        }

        override public function clone():Event
        {
            return new ReconnectFailedEvent(type);
        }
    }
}