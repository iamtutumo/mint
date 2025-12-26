# Credentials Setup Guide

This directory is used to store credentials for the n8n workflows. For security reasons, actual credentials should never be committed to version control. Instead, use this guide to set up the required credentials in your n8n instance.

## Required Credentials

### 1. WhatsApp API Credentials
**Name:** `whatsapp-credentials`  
**Type:** WhatsApp API  
**Required Fields:**
- `apiKey`: Your WhatsApp Business API key
- `apiUrl`: The base URL for the WhatsApp API (e.g., `https://api.whatsapp.com/v1`)
- `phoneNumberId`: Your WhatsApp Business phone number ID
- `businessAccountId`: Your WhatsApp Business account ID

### 2. API Authentication
**Name:** `api-credentials`  
**Type:** HTTP Basic Auth  
**Required Fields:**
- `user`: API username
- `password`: API password

### 3. Database Access
**Name:** `database-credentials`  
**Type:** Generic Credentials  
**Required Fields:**
- `host`: Database host
- `port`: Database port
- `database`: Database name
- `user`: Database username
- `password`: Database password

### 4. Email Service (for notifications)
**Name:** `email-credentials`  
**Type:** SMTP  
**Required Fields:**
- `host`: SMTP server
- `port`: SMTP port (typically 465 for SSL, 587 for TLS)
- `user`: Email username
- `password`: Email password
- `sender`: Sender email address

## Setup Instructions

1. In your n8n instance, go to the "Credentials" section
2. For each credential type listed above, click "Add Credential"
3. Select the appropriate credential type
4. Fill in the required fields with your actual credentials
5. Use the exact names specified above when connecting workflows to these credentials

## Security Best Practices

- Never commit actual credentials to version control
- Use environment variables for sensitive information
- Rotate credentials regularly
- Follow the principle of least privilege when setting up API permissions
- Use secure password managers to store and manage credentials

## Environment Variables (Alternative)

For enhanced security, you can use environment variables in your n8n instance:

```env
# WhatsApp API
WHATSAPP_API_KEY=your_api_key_here
WHATSAPP_API_URL=https://api.whatsapp.com/v1
WHATSAPP_PHONE_NUMBER_ID=your_phone_number_id
WHATSAPP_BUSINESS_ACCOUNT_ID=your_business_account_id

# API Authentication
API_USERNAME=your_username
API_PASSWORD=your_secure_password

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=your_database
DB_USER=db_user
DB_PASSWORD=db_password

# Email
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your_email@example.com
SMTP_PASSWORD=your_email_password
```

Then reference these variables in your credential setup using `process.env.VARIABLE_NAME`.
