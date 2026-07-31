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

    private const string SmtpServer = "smtp.gmail.com";
    private const int SmtpPort = 587;
    private const string SmtpUsername = "babygatemina@gmail.com";
    private const string SmtpPassword = "pbaxgkqloldgovhg";
    private const string FromEmail = "babygatemina@gmail.com";
    private const string FromName = "Diario di Viaggio";
    private const bool EnableSsl = true;
    private const string DefaultFrontendUrl = "https://alessandroclima.github.io";

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendPasswordResetEmailAsync(string toEmail, string userName, string resetToken)
    {
        try
        {
            var frontendUrl = _configuration["AppSettings:FrontendUrl"] ?? _configuration["FRONTEND_URL"] ?? DefaultFrontendUrl;

            var encodedToken = Uri.EscapeDataString(resetToken);
            var resetUrl = $"{frontendUrl.TrimEnd('/')}/reset-password?token={encodedToken}";

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

            using var client = new SmtpClient(SmtpServer, SmtpPort)
            {
                EnableSsl = EnableSsl,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(SmtpUsername, SmtpPassword)
            };

            using var message = new MailMessage
            {
                From = new MailAddress(FromEmail, FromName),
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
