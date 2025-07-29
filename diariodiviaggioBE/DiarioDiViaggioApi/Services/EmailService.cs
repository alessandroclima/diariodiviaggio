using System.Net;
using System.Net.Mail;

namespace DiarioDiViaggioApi.Services;

public interface IEmailService
{
    Task SendPasswordResetEmailAsync(string toEmail, string userName, string resetToken);
}

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendPasswordResetEmailAsync(string toEmail, string userName, string resetToken)
    {
        try
        {
            var smtpServer = _configuration["EmailSettings:SmtpServer"];
            var smtpPort = int.Parse(_configuration["EmailSettings:SmtpPort"] ?? "587");
            var smtpUsername = _configuration["EmailSettings:SmtpUsername"];
            var smtpPassword = _configuration["EmailSettings:SmtpPassword"];
            var fromEmail = _configuration["EmailSettings:FromEmail"];
            var fromName = _configuration["EmailSettings:FromName"];
            var enableSsl = bool.Parse(_configuration["EmailSettings:EnableSsl"] ?? "true");
            var frontendUrl = _configuration["AppSettings:FrontendUrl"];

            // Validate required configuration
            if (string.IsNullOrEmpty(smtpServer) || string.IsNullOrEmpty(smtpUsername) || 
                string.IsNullOrEmpty(smtpPassword) || string.IsNullOrEmpty(fromEmail))
            {
                _logger.LogWarning("Email configuration is incomplete. Password reset email not sent.");
                return;
            }

            var resetUrl = $"{frontendUrl}/reset-password?token={resetToken}";

            var subject = "Reset Your Password - Diario di Viaggio";
            var htmlBody = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Password Reset</title>
</head>
<body style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;'>
    <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px;'>
        <h2 style='color: #333; text-align: center; margin-bottom: 30px;'>Reset Your Password</h2>
        
        <p style='color: #666; font-size: 16px; line-height: 1.6;'>
            Hello {userName},
        </p>
        
        <p style='color: #666; font-size: 16px; line-height: 1.6;'>
            We received a request to reset your password for your Diario di Viaggio account. 
            Click the button below to create a new password:
        </p>
        
        <div style='text-align: center; margin: 40px 0;'>
            <a href='{resetUrl}' 
               style='background-color: #007bff; color: white; padding: 15px 30px; 
                      text-decoration: none; border-radius: 5px; font-weight: bold; 
                      display: inline-block;'>
                Reset Password
            </a>
        </div>
        
        <p style='color: #666; font-size: 14px; line-height: 1.6;'>
            If the button doesn't work, you can copy and paste this link into your browser:
        </p>
        
        <p style='color: #007bff; font-size: 14px; word-break: break-all; 
                  background-color: #f1f1f1; padding: 10px; border-radius: 5px;'>
            {resetUrl}
        </p>
        
        <p style='color: #666; font-size: 14px; line-height: 1.6; margin-top: 30px;'>
            <strong>Important:</strong> This link will expire in 1 hour for security reasons.
        </p>
        
        <p style='color: #666; font-size: 14px; line-height: 1.6;'>
            If you didn't request this password reset, you can safely ignore this email. 
            Your password will not be changed.
        </p>
        
        <hr style='border: none; border-top: 1px solid #eee; margin: 30px 0;'>
        
        <p style='color: #999; font-size: 12px; text-align: center;'>
            This email was sent from Diario di Viaggio. Please do not reply to this email.
        </p>
    </div>
</body>
</html>";

            var textBody = $@"
Hello {userName},

We received a request to reset your password for your Diario di Viaggio account.

To reset your password, please visit: {resetUrl}

Important: This link will expire in 1 hour for security reasons.

If you didn't request this password reset, you can safely ignore this email. Your password will not be changed.

Best regards,
Diario di Viaggio Team
";

            using var client = new SmtpClient(smtpServer, smtpPort)
            {
                EnableSsl = enableSsl,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(smtpUsername, smtpPassword)
            };

            using var message = new MailMessage
            {
                From = new MailAddress(fromEmail, fromName),
                Subject = subject,
                Body = htmlBody,
                IsBodyHtml = true
            };

            // Add plain text alternative
            var plainTextView = AlternateView.CreateAlternateViewFromString(textBody, null, "text/plain");
            message.AlternateViews.Add(plainTextView);

            message.To.Add(toEmail);

            await client.SendMailAsync(message);

            _logger.LogInformation("Password reset email sent successfully to {Email}", toEmail);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send password reset email to {Email}", toEmail);
            throw;
        }
    }
}
