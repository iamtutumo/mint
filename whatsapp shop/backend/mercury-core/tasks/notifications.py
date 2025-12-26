"""
Notification tasks for sending various types of notifications.

This module provides functionality to send different types of notifications
including emails, SMS, and push notifications.
"""
import logging
from typing import Dict, Any, List, Optional, Union
from datetime import datetime
from enum import Enum, auto
import json

# Set up logging
logger = logging.getLogger(__name__)

class NotificationType(Enum):
    """Types of notifications that can be sent."""
    EMAIL = auto()
    SMS = auto()
    PUSH = auto()
    WHATSAPP = auto()

class NotificationPriority(Enum):
    """Priority levels for notifications."""
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    URGENT = "urgent"

class NotificationStatus(Enum):
    """Status of a notification."""
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"
    DELIVERED = "delivered"
    READ = "read"

class NotificationTemplate(Enum):
    """Available notification templates."""
    ORDER_CONFIRMATION = "order_confirmation"
    ORDER_SHIPPED = "order_shipped"
    ORDER_DELIVERED = "order_delivered"
    PAYMENT_RECEIVED = "payment_received"
    PAYMENT_FAILED = "payment_failed"
    ACCOUNT_CREATED = "account_created"
    PASSWORD_RESET = "password_reset"
    BOOKING_CONFIRMATION = "booking_confirmation"
    BOOKING_REMINDER = "booking_reminder"
    BOOKING_CANCELLED = "booking_cancelled"
    INVENTORY_ALERT = "inventory_alert"
    PROMOTIONAL = "promotional"

class Notification:
    """Represents a notification to be sent."""
    
    def __init__(
        self,
        recipient: Union[str, List[str]],
        template: NotificationTemplate,
        context: Dict[str, Any],
        notification_type: NotificationType = NotificationType.EMAIL,
        priority: NotificationPriority = NotificationPriority.NORMAL,
        subject: Optional[str] = None,
        sender: Optional[str] = None,
        reply_to: Optional[str] = None,
        cc: Optional[List[str]] = None,
        bcc: Optional[List[str]] = None,
        attachments: Optional[List[Dict[str, Any]]] = None
    ):
        """
        Initialize a notification.
        
        Args:
            recipient: Email address, phone number, or user ID of the recipient
            template: The notification template to use
            context: Context data for the template
            notification_type: Type of notification (email, SMS, etc.)
            priority: Priority of the notification
            subject: Subject line (for email)
            sender: Sender's email/phone (optional)
            reply_to: Reply-to address (for email)
            cc: List of CC recipients (for email)
            bcc: List of BCC recipients (for email)
            attachments: List of attachments (for email)
        """
        if isinstance(recipient, str):
            recipient = [recipient]
        
        self.recipient = recipient
        self.template = template
        self.context = context
        self.notification_type = notification_type
        self.priority = priority
        self.subject = subject
        self.sender = sender
        self.reply_to = reply_to
        self.cc = cc or []
        self.bcc = bcc or []
        self.attachments = attachments or []
        self.status = NotificationStatus.PENDING
        self.sent_at = None
        self.metadata = {}
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the notification to a dictionary."""
        return {
            "recipient": self.recipient,
            "template": self.template.value,
            "context": self.context,
            "notification_type": self.notification_type.name,
            "priority": self.priority.value,
            "subject": self.subject,
            "sender": self.sender,
            "reply_to": self.reply_to,
            "cc": self.cc,
            "bcc": self.bcc,
            "status": self.status.value,
            "sent_at": self.sent_at.isoformat() if self.sent_at else None,
            "metadata": self.metadata
        }
    
    def __str__(self) -> str:
        """Return a string representation of the notification."""
        return f"<Notification {self.template.value} to {', '.join(self.recipient)}>"

class NotificationService:
    """Service for sending notifications."""
    
    def __init__(self, db_session=None):
        """
        Initialize the notification service.
        
        Args:
            db_session: Database session/connection (optional)
        """
        self.db_session = db_session
        self.providers = {
            NotificationType.EMAIL: self._send_email,
            NotificationType.SMS: self._send_sms,
            NotificationType.PUSH: self._send_push,
            NotificationType.WHATSAPP: self._send_whatsapp
        }
    
    async def send(self, notification: Notification) -> bool:
        """
        Send a notification.
        
        Args:
            notification: The notification to send
            
        Returns:
            True if the notification was sent successfully, False otherwise
        """
        try:
            logger.info(f"Sending {notification.notification_type.name} notification: {notification}")
            
            # Get the appropriate sender function for the notification type
            sender = self.providers.get(notification.notification_type)
            if not sender:
                raise ValueError(f"Unsupported notification type: {notification.notification_type}")
            
            # Send the notification
            success = await sender(notification)
            
            # Update the notification status
            notification.status = NotificationStatus.SENT if success else NotificationStatus.FAILED
            notification.sent_at = datetime.utcnow()
            
            # Log the result
            if success:
                logger.info(f"Successfully sent notification: {notification}")
            else:
                logger.error(f"Failed to send notification: {notification}")
            
            # In a real implementation, you would save the notification to the database
            # await self._save_notification(notification)
            
            return success
            
        except Exception as e:
            logger.error(f"Error sending notification {notification}: {str(e)}", exc_info=True)
            notification.status = NotificationStatus.FAILED
            notification.metadata["error"] = str(e)
            
            # In a real implementation, you would save the error to the database
            # await self._save_notification(notification)
            
            return False
    
    async def send_multiple(self, notifications: List[Notification]) -> Dict[str, int]:
        """
        Send multiple notifications.
        
        Args:
            notifications: List of notifications to send
            
        Returns:
            Dictionary with counts of sent and failed notifications
        """
        results = {"total": len(notifications), "sent": 0, "failed": 0}
        
        for notification in notifications:
            success = await self.send(notification)
            if success:
                results["sent"] += 1
            else:
                results["failed"] += 1
        
        return results
    
    async def _send_email(self, notification: Notification) -> bool:
        """
        Send an email notification.
        
        Args:
            notification: The email notification to send
            
        Returns:
            True if the email was sent successfully, False otherwise
        """
        # In a real implementation, this would use an email service like SendGrid,
        # Mailgun, or AWS SES to send the email
        try:
            logger.info(
                f"Sending email to {', '.join(notification.recipient)}: "
                f"{notification.subject}"
            )
            
            # Mock implementation - in a real app, this would actually send an email
            # For example, using SendGrid:
            # from sendgrid import SendGridAPIClient
            # from sendgrid.helpers.mail import Mail
            # 
            # message = Mail(
            #     from_email=notification.sender,
            #     to_emails=notification.recipient,
            #     subject=notification.subject,
            #     html_content=self._render_template(notification.template, notification.context)
            # )
            # 
            # if notification.cc:
            #     message.cc = notification.cc
            # if notification.bcc:
            #     message.bcc = notification.bcc
            # if notification.reply_to:
            #     message.reply_to = notification.reply_to
            # 
            # for attachment in notification.attachments:
            #     message.attachment = attachment
            # 
            # sg = SendGridAPIClient(api_key=settings.SENDGRID_API_KEY)
            # response = sg.send(message)
            # return response.status_code == 202
            
            # For now, just log and return True to simulate success
            return True
            
        except Exception as e:
            logger.error(f"Error sending email: {str(e)}", exc_info=True)
            return False
    
    async def _send_sms(self, notification: Notification) -> bool:
        """
        Send an SMS notification.
        
        Args:
            notification: The SMS notification to send
            
        Returns:
            True if the SMS was sent successfully, False otherwise
        """
        # In a real implementation, this would use an SMS service like Twilio,
        # Nexmo, or AWS SNS to send the SMS
        try:
            logger.info(f"Sending SMS to {', '.join(notification.recipient)}")
            
            # Mock implementation - in a real app, this would actually send an SMS
            # For example, using Twilio:
            # from twilio.rest import Client
            # 
            # client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
            # 
            # for recipient in notification.recipient:
            #     message = client.messages.create(
            #         body=self._render_template(notification.template, notification.context),
            #         from_=settings.TWILIO_PHONE_NUMBER,
            #         to=recipient
            #     )
            #     
            #     if not message.sid:
            #         return False
            
            # For now, just return True to simulate success
            return True
            
        except Exception as e:
            logger.error(f"Error sending SMS: {str(e)}", exc_info=True)
            return False
    
    async def _send_push(self, notification: Notification) -> bool:
        """
        Send a push notification.
        
        Args:
            notification: The push notification to send
            
        Returns:
            True if the push notification was sent successfully, False otherwise
        """
        # In a real implementation, this would use a push notification service
        # like Firebase Cloud Messaging (FCM) or Apple Push Notification Service (APNS)
        try:
            logger.info(f"Sending push notification to {len(notification.recipient)} devices")
            
            # Mock implementation - in a real app, this would actually send a push notification
            # For example, using FCM:
            # from firebase_admin import messaging
            # 
            # message = messaging.MulticastMessage(
            #     notification=messaging.Notification(
            #         title=notification.context.get('title', ''),
            #         body=self._render_template(notification.template, notification.context)
            #     ),
            #     tokens=notification.recipient,
            #     data=notification.context.get('data', {})
            # )
            # 
            # response = messaging.send_multicast(message)
            # return response.failure_count == 0
            
            # For now, just return True to simulate success
            return True
            
        except Exception as e:
            logger.error(f"Error sending push notification: {str(e)}", exc_info=True)
            return False
    
    async def _send_whatsapp(self, notification: Notification) -> bool:
        """
        Send a WhatsApp message.
        
        Args:
            notification: The WhatsApp message to send
            
        Returns:
            True if the message was sent successfully, False otherwise
        """
        # In a real implementation, this would use the WhatsApp Business API
        # or a service like Twilio for WhatsApp
        try:
            logger.info(f"Sending WhatsApp message to {', '.join(notification.recipient)}")
            
            # Mock implementation - in a real app, this would actually send a WhatsApp message
            # For example, using Twilio for WhatsApp:
            # from twilio.rest import Client
            # 
            # client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
            # 
            # for recipient in notification.recipient:
            #     message = client.messages.create(
            #         body=self._render_template(notification.template, notification.context),
            #         from_=f"whatsapp:{settings.TWILIO_WHATSAPP_NUMBER}",
            #         to=f"whatsapp:{recipient}"
            #     )
            #     
            #     if not message.sid:
            #         return False
            
            # For now, just return True to simulate success
            return True
            
        except Exception as e:
            logger.error(f"Error sending WhatsApp message: {str(e)}", exc_info=True)
            return False
    
    def _render_template(self, template_name: str, context: Dict[str, Any]) -> str:
        """
        Render a notification template with the given context.
        
        Args:
            template_name: Name of the template to render
            context: Context data for the template
            
        Returns:
            Rendered template as a string
        """
        # In a real implementation, this would use a templating engine like Jinja2
        # to render the template with the provided context
        # For example:
        # from jinja2 import Environment, FileSystemLoader
        # 
        # env = Environment(loader=FileSystemLoader('templates/notifications'))
        # template = env.get_template(f"{template_name}.html")
        # return template.render(**context)
        
        # For now, just return a simple string representation
        return f"[{template_name}] {json.dumps(context, indent=2)}"

# Singleton instance
notification_service = NotificationService()

# Helper functions
async def send_notification(
    recipient: Union[str, List[str]],
    template: Union[str, NotificationTemplate],
    context: Dict[str, Any],
    notification_type: Union[str, NotificationType] = NotificationType.EMAIL,
    **kwargs
) -> bool:
    """
    Helper function to send a notification.
    
    Args:
        recipient: Email address, phone number, or user ID of the recipient
        template: The notification template to use
        context: Context data for the template
        notification_type: Type of notification (email, SMS, etc.)
        **kwargs: Additional arguments to pass to the Notification constructor
        
    Returns:
        True if the notification was sent successfully, False otherwise
    """
    if isinstance(template, str):
        try:
            template = NotificationTemplate(template)
        except ValueError:
            logger.error(f"Invalid template: {template}")
            return False
    
    if isinstance(notification_type, str):
        try:
            notification_type = NotificationType[notification_type.upper()]
        except KeyError:
            logger.error(f"Invalid notification type: {notification_type}")
            return False
    
    notification = Notification(
        recipient=recipient,
        template=template,
        context=context,
        notification_type=notification_type,
        **kwargs
    )
    
    return await notification_service.send(notification)

async def send_bulk_notifications(notifications: List[Dict[str, Any]]) -> Dict[str, int]:
    """
    Helper function to send multiple notifications.
    
    Args:
        notifications: List of notification dictionaries
        
    Returns:
        Dictionary with counts of sent and failed notifications
    """
    notification_objects = []
    
    for notification_data in notifications:
        try:
            # Convert string values to enums
            if "template" in notification_data and isinstance(notification_data["template"], str):
                notification_data["template"] = NotificationTemplate(notification_data["template"])
            
            if "notification_type" in notification_data and isinstance(notification_data["notification_type"], str):
                notification_data["notification_type"] = NotificationType[notification_data["notification_type"].upper()]
            
            if "priority" in notification_data and isinstance(notification_data["priority"], str):
                notification_data["priority"] = NotificationPriority(notification_data["priority"].lower())
            
            notification = Notification(**notification_data)
            notification_objects.append(notification)
            
        except Exception as e:
            logger.error(f"Error creating notification from {notification_data}: {str(e)}")
    
    return await notification_service.send_multiple(notification_objects)
