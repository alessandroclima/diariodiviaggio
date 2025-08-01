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
            var messageBody = $@"Hello {userName},

We received a request to reset your password for your Diario di Viaggio account.

To reset your password, please visit the following link:
{resetUrl}

IMPORTANT: This link will expire in 1 hour for security reasons.

If you didn't request this password reset, you can safely ignore this email. Your password will not be changed.

Best regards,
Diario di Viaggio Team

---
This email was sent from Diario di Viaggio. Please do not reply to this email.";

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
                Body = messageBody,
                IsBodyHtml = false
            };

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
