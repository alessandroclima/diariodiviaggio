# Production Configuration Guide

This document explains how to configure the Diario Di Viaggio API for production deployment.

## Environment Variables

The production configuration uses environment variables for sensitive data. Set these in your production environment:

### Database Configuration
- `DATABASE_CONNECTION_STRING`: PostgreSQL connection string for production database
  - Example: `Host=your-postgres-server.com;Database=diariodiviaggio_prod;Username=your_user;Password=your_password;SSL Mode=Require;`

### JWT Configuration
- `JWT_SECRET_KEY`: Strong secret key for JWT token signing (minimum 32 characters)
  - Generate with: `openssl rand -base64 32`
- `JWT_ISSUER`: Your application's issuer identifier
  - Example: `https://yourdomain.com`
- `JWT_AUDIENCE`: Your application's audience identifier
  - Example: `https://yourdomain.com/api`

### Email Configuration (SMTP)
- `SMTP_SERVER`: SMTP server hostname
  - Gmail: `smtp.gmail.com`
  - Outlook: `smtp-mail.outlook.com`
- `SMTP_PORT`: SMTP server port
  - Gmail/TLS: `587`
  - Gmail/SSL: `465`
- `EMAIL_SENDER_NAME`: Display name for SMTP authentication
  - Example: `babygatemina@gmail.com`
- `EMAIL_SENDER_PASSWORD`: SMTP authentication password (use app passwords for Gmail)
- `EMAIL_FROM`: Email address used as sender
  - Example: `noreply@yourdomain.com`
- `NAME_FROM`: Display name for outgoing emails
  - Example: `Diario Di Viaggio`

### Frontend Configuration
- `FRONTEND_URL`: Production frontend URL
  - Example: `https://alessandroclima.github.io` (for GitHub Pages)
  - **Important**: This must match your deployed frontend URL exactly to avoid CORS errors

## Azure App Service Configuration

If deploying to Azure App Service, set these as Application Settings:

1. Go to Azure Portal → Your App Service → Configuration → Application settings
2. Add each environment variable as a new application setting
3. Restart the app service after adding all settings

## Local Production Testing

To test the production configuration locally:

1. Create a `.env` file in the project root (don't commit this):
```
DATABASE_CONNECTION_STRING=your_local_prod_db_connection
JWT_SECRET_KEY=your_jwt_secret_here
JWT_ISSUER=https://localhost:5001
JWT_AUDIENCE=https://localhost:5001/api
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
EMAIL_SENDER_NAME=your-email@gmail.com
EMAIL_SENDER_PASSWORD=your-app-password
EMAIL_FROM=your-email@gmail.com
NAME_FROM=Diario Di Viaggio
FRONTEND_URL=https://localhost:4200
```

2. Run with production environment:
```bash
$env:ASPNETCORE_ENVIRONMENT="Production"
dotnet run
```

## Security Considerations

1. **Never commit sensitive data** to version control
2. Use **strong passwords** and **app passwords** for email services
3. Ensure **database connections use SSL** in production
4. Set **secure JWT secrets** (minimum 256 bits)
5. Use **HTTPS only** in production
6. Consider using **Azure Key Vault** for sensitive configuration

## Deployment Checklist

- [ ] Database server accessible from production environment
- [ ] All environment variables configured
- [ ] SMTP settings tested
- [ ] JWT configuration verified
- [ ] Frontend URL matches deployed frontend
- [ ] SSL/HTTPS enabled
- [ ] Logs configured for production monitoring

## Troubleshooting CORS Issues

If you encounter CORS errors like "No 'Access-Control-Allow-Origin' header is present":

1. **Verify Environment Variables in Azure App Service**:
   - Go to Azure Portal → Your App Service → Configuration → Application Settings
   - Ensure `FRONTEND_URL` is set to your exact frontend URL (e.g., `https://alessandroclima.github.io`)
   - Restart your app service after adding/changing environment variables

2. **Check CORS Configuration**:
   - The backend automatically includes your `FRONTEND_URL` in CORS origins
   - Common frontend URLs that should work:
     - `https://alessandroclima.github.io` (GitHub Pages)
     - `https://yourdomain.com` (Custom domain)
     - `http://localhost:4200` (Local development)

3. **Azure App Service Specific Steps**:
   ```bash
   # Set the environment variable via Azure CLI
   az webapp config appsettings set --resource-group your-resource-group --name your-app-name --settings FRONTEND_URL="https://alessandroclima.github.io"
   
   # Restart the app service
   az webapp restart --resource-group your-resource-group --name your-app-name
   ```

4. **Verify the Configuration**:
   - Check your app logs to ensure the environment variables are being read correctly
   - Test the API endpoints directly to ensure they're responding
   - Use browser developer tools to inspect CORS headers in the response
