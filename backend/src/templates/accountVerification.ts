export const accountVerificationTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verify Your Nexweb Account</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f7f7f7; color: #333333;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr>
            <td align="center" style="padding: 20px 0;">
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="background-color: #056A1E; padding: 30px 40px; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: 700;">Nexweb</h1>
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px;">
                            <h2 style="margin-top: 0; margin-bottom: 20px; color: #333333; font-size: 24px;">Verify Your Account</h2>
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                Thank you for registering with Nexweb. To complete your account setup, please use the verification code below:
                            </p>
                            
                            <!-- OTP Code Box -->
                            <div style="background-color: #f7f7f7; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0;">
                                <p style="margin: 0 0 10px; font-size: 14px; color: #666666;">Your verification code is:</p>
                                <div style="font-family: 'Courier New', monospace; font-size: 32px; font-weight: 700; letter-spacing: 5px; color: #056A1E;">
                                    {code}
                                </div>
                                <p style="margin: 10px 0 0; font-size: 14px; color: #666666;">This code will expire in 10 minutes</p>
                            </div>
                            
                            <p style="margin-bottom: 25px; font-size: 16px; line-height: 1.5; color: #555555;">
                                If you didn't request this verification code, please ignore this email or contact our support team if you have concerns.
                            </p>
                            
                            <!-- Button -->
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                                <tr>
                                    <td align="center" style="padding: 20px 0 30px;">
                                        <a href="#" style="display: inline-block; background-color: #056A1E; color: #ffffff; text-decoration: none; font-weight: 600; padding: 12px 30px; border-radius: 4px; font-size: 16px;">Visit Nexweb</a>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f7f7f7; padding: 30px 40px; text-align: center; border-top: 1px solid #eeeeee;">
                            <p style="margin: 0 0 15px; font-size: 14px; color: #666666;">
                                &copy; 2024 Nexweb. All rights reserved.
                            </p>
                            <p style="margin: 0; font-size: 14px; color: #666666;">
                                If you have any questions, please contact our <a href="#" style="color: #056A1E; text-decoration: none;">support team</a>.
                            </p>
                            <div style="margin-top: 20px;">
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Privacy Policy</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Terms of Service</a>
                                <a href="#" style="display: inline-block; margin: 0 8px; color: #056A1E; text-decoration: none; font-size: 14px;">Unsubscribe</a>
                            </div>
                        </td>
                    </tr>
                </table>
                
                <!-- Alert Banner -->
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="margin-top: 20px;">
                    <tr>
                        <td style="background-color: #FFF5F5; border-left: 4px solid #FA2F2B; padding: 15px 20px; border-radius: 4px;">
                            <p style="margin: 0; font-size: 14px; line-height: 1.5; color: #333333;">
                                <span style="color: #FA2F2B; font-weight: 600;">Security Notice:</span> Nexweb will never ask for your password or personal financial information via email.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`;
